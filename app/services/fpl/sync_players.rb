require "net/http"
require "json"

module Fpl
  class SyncPlayers < ApplicationService
    FPL_API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"
    POSITION_MAP = { 1 => "goalkeeper", 2 => "defender", 3 => "midfielder", 4 => "forward" }.freeze

    def call
      Rails.logger.info "Starting FPL player sync..."

      data = fetch_fpl_data
      return false unless data

      process_sync(data)
      true
    rescue => e
      log_error(e)
      false
    end

    private

    def process_sync(data)
      sync_teams(data["teams"])
      sync_players(data["elements"], build_teams_hash(data["teams"]))
      sync_availability_statistics(data["elements"])
      Rails.logger.info "FPL player sync completed. Total players: #{Player.count}"
    end

    def log_error(error)
      Rails.logger.error "FPL sync failed: #{error.message}"
      Rails.logger.error "Backtrace: #{error.backtrace.join("\n")}"
    end

    def fetch_fpl_data
      uri = URI(FPL_API_URL)
      response = make_http_request(uri)
      response.code == "200" ? JSON.parse(response.body) : log_api_error(response)
    end

    def make_http_request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"
        http.request(request)
      end
    end

    def log_api_error(response)
      Rails.logger.error "FPL API returned #{response.code}: #{response.message}"
      nil
    end

    def sync_teams(teams_data)
      Rails.logger.info "Syncing teams..."
      teams_data.each { |team_data| sync_team(team_data) }
      Rails.logger.info "Teams sync completed. Total teams: #{Team.count}"
    end

    def sync_team(team_data)
      team = Team.find_or_initialize_by(fpl_id: team_data["id"])
      team.assign_attributes(team_attributes(team_data))
      log_team_result(team, team_data)
    end

    def team_attributes(data)
      { name: data["name"], short_name: data["short_name"], code: data["code"] }
    end

    def log_team_result(team, data)
      if team.save
        Rails.logger.debug "Synced team: #{team.name} (#{team.short_name})"
      else
        Rails.logger.error "Failed to sync team #{data['name']}: #{team.errors.full_messages.join(', ')}"
      end
    end

    def build_teams_hash(teams_data)
      teams_data.to_h { |team| [ team["id"], team["name"] ] }
    end

    def sync_players(elements, _teams)
      counts = { success: 0, skip: 0, error: 0 }
      elements.each { |element| sync_player(element, counts) }
      Rails.logger.info "Player sync results: #{counts[:success]} synced, #{counts[:skip]} skipped, #{counts[:error]} errors"
    end

    def sync_player(element, counts)
      attrs = build_player_attributes(element)
      return counts[:skip] += 1 unless attrs

      player = Player.find_or_initialize_by(fpl_id: element["id"])
      player.assign_attributes(attrs)
      save_player(player, element, counts)
    rescue => e
      Rails.logger.error "Exception syncing player #{element['first_name']} #{element['second_name']}: #{e.message}"
      counts[:error] += 1
    end

    def build_player_attributes(element)
      position = POSITION_MAP[element["element_type"]]
      team_record = Team.find_by(fpl_id: element["team"])
      return nil unless position && team_record

      { first_name: element["first_name"], last_name: element["second_name"],
        short_name: element["web_name"] || element["second_name"], code: element["code"],
        team: team_record, position: position }
    end

    def save_player(player, element, counts)
      if player.save
        log_player_success(player)
        counts[:success] += 1
      else
        log_player_error(player, element)
        counts[:error] += 1
      end
    end

    def log_player_success(player)
      Rails.logger.debug "Synced player: #{player.first_name} #{player.last_name} (#{player.team.name}, #{player.position})"
    end

    def log_player_error(player, element)
      Rails.logger.error "Failed to sync player #{element['first_name']} #{element['second_name']}: #{player.errors.full_messages.join(', ')}"
    end

    def sync_availability_statistics(elements)
      current_gw = Gameweek.current_gameweek
      next_gw = Gameweek.next_gameweek
      return unless current_gw || next_gw

      availability_data = build_availability_data(elements, current_gw, next_gw)
      return if availability_data.empty?

      Statistic.upsert_all(availability_data, unique_by: %i[player_id gameweek_id type])
      log_availability_sync(availability_data.size, current_gw, next_gw)
    end

    def build_availability_data(elements, current_gw, next_gw)
      players_by_fpl_id = Player.where(fpl_id: elements.map { |e| e["id"] }).pluck(:fpl_id, :id).to_h
      now = Time.current

      elements.flat_map do |element|
        player_id = players_by_fpl_id[element["id"]]
        next [] unless player_id

        build_player_availability(element, player_id, current_gw, next_gw, now)
      end
    end

    def build_player_availability(element, player_id, current_gw, next_gw, now)
      data = []
      data << availability_record(player_id, current_gw, element["chance_of_playing_this_round"], now) if current_gw
      data << availability_record(player_id, next_gw, element["chance_of_playing_next_round"], now) if next_gw
      data.compact
    end

    def availability_record(player_id, gameweek, chance, now)
      return nil unless chance.present?

      { player_id: player_id, gameweek_id: gameweek.id, type: "chance_of_playing",
        value: chance.to_f, created_at: now, updated_at: now }
    end

    def log_availability_sync(count, current_gw, next_gw)
      gameweeks = [ current_gw&.fpl_id, next_gw&.fpl_id ].compact.join(", ")
      Rails.logger.info "Synced #{count} availability statistics for gameweeks #{gameweeks}"
    end
  end
end
