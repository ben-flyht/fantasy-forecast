require "net/http"
require "json"

module Fpl
  class SyncPlayers
  FPL_API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"

  def self.call
    new.call
  end

  def call
    Rails.logger.info "Starting FPL player sync..."

    data = fetch_fpl_data
    return false unless data

    # Sync teams first
    sync_teams(data["teams"])

    teams = build_teams_hash(data["teams"])
    elements = data["elements"]

    sync_players(elements, teams)

    Rails.logger.info "FPL player sync completed. Total players: #{Player.count}"
    true
  rescue => e
    Rails.logger.error "FPL sync failed: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
    false
  end

  private

  def fetch_fpl_data
    uri = URI(FPL_API_URL)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Fantasy Forecast App"

      response = http.request(request)

      if response.code == "200"
        JSON.parse(response.body)
      else
        Rails.logger.error "FPL API returned #{response.code}: #{response.message}"
        nil
      end
    end
  end

  def sync_teams(teams_data)
    Rails.logger.info "Syncing teams..."

    teams_data.each do |team_data|
      team = Team.find_or_initialize_by(fpl_id: team_data["id"])

      team.assign_attributes(
        name: team_data["name"],
        short_name: team_data["short_name"],
        code: team_data["code"]
      )

      if team.save
        Rails.logger.debug "Synced team: #{team.name} (#{team.short_name})"
      else
        Rails.logger.error "Failed to sync team #{team_data['name']}: #{team.errors.full_messages.join(', ')}"
      end
    end

    Rails.logger.info "Teams sync completed. Total teams: #{Team.count}"
  end

  def build_teams_hash(teams_data)
    teams_hash = {}
    teams_data.each do |team|
      teams_hash[team["id"]] = team["name"]
    end
    teams_hash
  end

  def sync_players(elements, teams)
    position_map = {
      1 => "goalkeeper",
      2 => "defender",
      3 => "midfielder",
      4 => "forward"
    }

    success_count = 0
    skip_count = 0
    error_count = 0

    elements.each do |element|
      begin
        fpl_id = element["id"]
        first_name = element["first_name"]
        last_name = element["second_name"]
        short_name = element["web_name"] || element["second_name"] # Fallback to second_name if web_name missing
        code = element["code"]
        team_fpl_id = element["team"]
        position = position_map[element["element_type"]]

        # Find the team record
        team_record = Team.find_by(fpl_id: team_fpl_id)

        # Skip if we can't determine position or team
        unless position && team_record
          Rails.logger.warn "Skipping player #{first_name} #{last_name}: position=#{position}, team_record=#{team_record&.name}"
          skip_count += 1
          next
        end

        player_attributes = {
          first_name: first_name,
          last_name: last_name,
          short_name: short_name,
          code: code,
          team: team_record,
          position: position
        }

        player = Player.find_or_initialize_by(fpl_id: fpl_id)
        player.assign_attributes(player_attributes)

        if player.save
          Rails.logger.debug "Synced player: #{first_name} #{last_name} (#{short_name}) (#{team_record.name}, #{position})"
          success_count += 1
        else
          Rails.logger.error "Failed to sync player #{first_name} #{last_name}: #{player.errors.full_messages.join(', ')}"
          error_count += 1
        end
      rescue => e
        Rails.logger.error "Exception syncing player #{element['first_name']} #{element['second_name']}: #{e.message}"
        error_count += 1
      end
    end

    Rails.logger.info "Player sync results: #{success_count} synced, #{skip_count} skipped, #{error_count} errors"
  end
  end
end
