module Fpl
  class SyncPlayers < ApplicationService
    POSITION_MAP = { 1 => "goalkeeper", 2 => "defender", 3 => "midfielder", 4 => "forward" }.freeze

    def initialize(api: Api.new)
      @api = api
    end

    def call
      Rails.logger.info "Starting FPL player sync..."

      data = @api.bootstrap
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
      sync_snapshot_statistics(data["elements"])
      Rails.logger.info "FPL player sync completed. Total players: #{Player.count}"
    end

    def log_error(error)
      Rails.logger.error "FPL sync failed: #{error.message}"
      Rails.logger.error "Backtrace: #{error.backtrace.join("\n")}"
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
      { name: data["name"], short_name: data["short_name"], code: data["code"],
        played: data["played"], win: data["win"], draw: data["draw"], loss: data["loss"],
        points: data["points"], league_position: data["position"], form: data["form"],
        unavailable: data["unavailable"] || false }.merge(strength_attributes(data))
    end

    STRENGTH_FIELDS = %w[
      strength strength_overall_home strength_overall_away
      strength_attack_home strength_attack_away strength_defence_home strength_defence_away
    ].freeze

    # FPL fills these in as a season gets going and publishes noughts in the
    # meantime, field by field: over this summer the overall ratings are already
    # there while attack and defence are still zero. A nought means "not published
    # yet", not a verdict on the club, so it must never overwrite what we hold.
    def strength_attributes(data)
      STRENGTH_FIELDS.filter_map { |field| [ field.to_sym, data[field] ] if data[field].to_i.positive? }.to_h
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
        team: team_record, position: position }.merge(fpl_attributes(element))
    end

    # What FPL says about the player himself, as opposed to what he has done.
    # Text, dates and categories, none of which fit a decimal statistic.
    def fpl_attributes(element)
      {
        news: element["news"].presence, news_added: element["news_added"],
        status: element["status"], birth_date: element["birth_date"],
        region: element["region"], team_join_date: element["team_join_date"],
        squad_number: element["squad_number"],
        selectable: element.fetch("can_select", true), departed: element.fetch("removed", false)
      }
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

      log_availability_sync(Statistic.store(availability_data), current_gw, next_gw)
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
      Rails.logger.info "#{count} availability statistics changed for gameweeks #{gameweeks}"
    end

    SNAPSHOT_STATS = {
      "form" => "form",
      "points_per_game" => "points_per_game",
      "now_cost" => "now_cost",
      "selected_by_percent" => "selected_by_percent",
      "transfers_in_event" => "transfers_in",
      "transfers_out_event" => "transfers_out",
      "ep_next" => "ep_next", # FPL's own expected points for the next GW; cold-start seed
      # Per-90 rates for the underlying-quality concept (a rate, not a total).
      "expected_goals_per_90" => "expected_goals_per_90",
      "expected_goal_involvements_per_90" => "expected_goal_involvements_per_90",
      "expected_goals_conceded_per_90" => "expected_goals_conceded_per_90",
      "saves_per_90" => "saves_per_90",
      "clean_sheets_per_90" => "clean_sheets_per_90",
      "defensive_contribution_per_90" => "defensive_contribution_per_90",
      # Minutes-security signals. season_minutes is the running total for the
      # campaign, named apart from the per-gameweek "minutes" stat that
      # SyncPerformances writes so the two cannot collide.
      "starts_per_90" => "starts_per_90",
      "minutes" => "season_minutes",
      # Running points total for the campaign, named apart from the per-gameweek
      # "total_points" stat that SyncPerformances writes.
      "total_points" => "season_points",
      # Bonus points are a tenth of a good player's return and are not in any of the
      # per-90 rates FPL publishes, so they have to be counted separately.
      "bonus" => "season_bonus",
      # Set-piece duty feeds underlying quality (1 = first choice). Nil when not on duty.
      "penalties_order" => "penalties_order",
      "corners_and_indirect_freekicks_order" => "corners_freekicks_order",
      "direct_freekicks_order" => "direct_freekicks_order"
    }.freeze

    def sync_snapshot_statistics(elements)
      # Pre-season there is no current gameweek yet, but the market snapshot
      # (form, ownership, per-90 rates) is already meaningful, so attach it to
      # the upcoming gameweek. This is what the cold-start concept tiers read.
      snapshot_gw = Gameweek.current_gameweek || Gameweek.next_gameweek
      return unless snapshot_gw

      players_by_fpl_id = Player.where(fpl_id: elements.map { |e| e["id"] }).pluck(:fpl_id, :id).to_h
      data = build_snapshot_data(elements, players_by_fpl_id, snapshot_gw)
      return if data.empty?

      Rails.logger.info "#{Statistic.store(data)} of #{data.size} snapshot statistics changed " \
                        "for gameweek #{snapshot_gw.fpl_id}"
    end

    def build_snapshot_data(elements, players_by_fpl_id, gameweek)
      now = Time.current

      elements.flat_map do |element|
        player_id = players_by_fpl_id[element["id"]]
        next [] unless player_id

        build_player_snapshots(element, player_id, gameweek, now)
      end
    end

    def build_player_snapshots(element, player_id, gameweek, now)
      SNAPSHOT_STATS.filter_map do |api_key, stat_type|
        value = element[api_key]
        next unless value.present?

        { player_id: player_id, gameweek_id: gameweek.id, type: stat_type,
          value: value.to_f, created_at: now, updated_at: now }
      end
    end
  end
end
