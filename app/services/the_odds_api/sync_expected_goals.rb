module TheOddsApi
  class SyncExpectedGoals < ApplicationService
    TEAM_NAME_VARIATIONS = {
      "manchesterunited" => %w[manutd manunited],
      "manchestercity" => %w[mancity],
      "tottenhamhotspur" => %w[tottenham spurs],
      "wolverhamptonwanderers" => %w[wolves wolverhampton],
      "brightonandhovealbin" => %w[brighton],
      "westhamunited" => %w[westham],
      "newcastleunited" => %w[newcastle],
      "nottinghamforest" => %w[nottmforest forest],
      "afcbournemouth" => %w[bournemouth],
      "crystalpalace" => %w[palace],
      "leicestercity" => %w[leicester],
      "leedsunited" => %w[leeds],
      "ipswichtown" => %w[ipswich]
    }.freeze

    def initialize(gameweek: nil)
      @gameweek = gameweek || Gameweek.next_gameweek || Gameweek.current_gameweek
    end

    def call
      return false unless @gameweek

      log_start
      sync_all_matches
    rescue Client::Error => e
      Rails.logger.error "The Odds API error: #{e.message}"
      false
    end

    private

    def log_start
      Rails.logger.info "Syncing expected goals from The Odds API (Pinnacle) for #{@gameweek.name}..."
    end

    def sync_all_matches
      client = Client.new
      events = client.events

      return log_no_events if events.nil? || events.empty?

      process_matches(client, events)
    end

    def log_no_events
      Rails.logger.warn "No EPL events found from The Odds API"
      false
    end

    def process_matches(client, events)
      Rails.logger.info "Found #{events.size} EPL events from The Odds API"

      matches = Match.includes(:home_team, :away_team).where(gameweek: @gameweek)
      synced_count = sync_matches(client, matches, events)

      log_quota(client)
      Rails.logger.info "Synced expected goals for #{synced_count}/#{matches.count} matches"
      true
    end

    def sync_matches(client, matches, events)
      matches.count { |match| sync_match_safely(client, match, events) }
    end

    def sync_match_safely(client, match, events)
      sync_match(client, match, events)
    rescue => e
      Rails.logger.error "Failed to sync odds for #{match.home_team.short_name} vs #{match.away_team.short_name}: #{e.message}"
      false
    end

    def sync_match(client, match, events)
      event = find_matching_event(match, events)
      return log_no_event(match) unless event

      log_event_link(match, event["id"])
      update_match_xg(client, match, event)
    end

    def find_matching_event(match, events)
      events.find do |event|
        home_matches?(event["home_team"], match.home_team) &&
          away_matches?(event["away_team"], match.away_team)
      end
    end

    def home_matches?(api_team, db_team)
      team_matches?(api_team, db_team)
    end

    def away_matches?(api_team, db_team)
      team_matches?(api_team, db_team)
    end

    def team_matches?(api_name, db_team)
      normalized_api = normalize(api_name)
      normalized_db = normalize(db_team.name)
      normalized_short = normalize(db_team.short_name)

      normalized_api.include?(normalized_db) ||
        normalized_db.include?(normalized_api) ||
        normalized_api.include?(normalized_short) ||
        fuzzy_match?(normalized_api, normalized_db)
    end

    def normalize(name)
      name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    def fuzzy_match?(api_name, db_name)
      TEAM_NAME_VARIATIONS.any? do |full, shorts|
        name_matches_variation?(api_name, full, shorts) &&
          name_matches_variation?(db_name, full, shorts)
      end
    end

    def name_matches_variation?(name, full, shorts)
      name.include?(full) || shorts.any? { |s| name.include?(s) }
    end

    def log_no_event(match)
      Rails.logger.warn "No event found for #{match.home_team.name} vs #{match.away_team.name}"
      false
    end

    def log_event_link(match, event_id)
      Rails.logger.info "Linked #{match.home_team.short_name} vs #{match.away_team.short_name} to event #{event_id}"
    end

    def update_match_xg(client, match, event)
      event_odds = client.event_odds(event_id: event["id"])
      return log_no_odds(event["id"]) if event_odds.dig("bookmakers")&.empty?

      result = ExpectedGoalsCalculator.call(
        event_data: event_odds,
        home_team: event["home_team"],
        away_team: event["away_team"]
      )

      return log_no_xg(match) unless result

      save_match_xg(match, result)
    end

    def log_no_odds(event_id)
      Rails.logger.warn "No odds data for event #{event_id}"
      false
    end

    def log_no_xg(match)
      Rails.logger.warn "Could not calculate xG for #{match.home_team.short_name} vs #{match.away_team.short_name}"
      false
    end

    def save_match_xg(match, result)
      match.update!(
        home_team_expected_goals: result[:home_xg],
        away_team_expected_goals: result[:away_xg]
      )

      log_result(match, result)
      true
    end

    def log_result(match, result)
      msg = "#{match.home_team.short_name} vs #{match.away_team.short_name}: " \
            "xG #{result[:home_xg]} - #{result[:away_xg]}"

      if result[:home_clean_sheet_probability]
        msg += " | CS%: #{(result[:home_clean_sheet_probability] * 100).round(1)}% - " \
               "#{(result[:away_clean_sheet_probability] * 100).round(1)}%"
      end

      Rails.logger.info msg
    end

    def log_quota(client)
      if client.remaining_requests
        Rails.logger.info "API quota: #{client.remaining_requests} requests remaining"
      end
    end
  end
end
