module ApiFootball
  class SyncExpectedGoals < ApplicationService
    PREMIER_LEAGUE_ID = 39

    def initialize(gameweek: nil, season: nil)
      @gameweek = gameweek || Gameweek.next_gameweek || Gameweek.current_gameweek
      @season = season || current_season
    end

    def call
      return false unless @gameweek

      log_start
      sync_all_matches
    rescue Client::Error => e
      Rails.logger.error "API-Football error: #{e.message}"
      false
    end

    private

    def log_start
      Rails.logger.info "Syncing API-Football expected goals for #{@gameweek.name}..."
    end

    def sync_all_matches
      client = Client.new
      fixtures = fetch_fixtures(client)

      return log_no_fixtures if fixtures.nil? || fixtures.empty?

      process_matches(client, fixtures)
    end

    def log_no_fixtures
      Rails.logger.warn "No fixtures found from API-Football"
      false
    end

    def process_matches(client, fixtures)
      Rails.logger.info "Found #{fixtures.size} fixtures from API-Football"

      matches = Match.includes(:home_team, :away_team).where(gameweek: @gameweek)
      synced_count = sync_matches(client, matches, fixtures)

      Rails.logger.info "Synced expected goals for #{synced_count}/#{matches.count} matches"
      true
    end

    def sync_matches(client, matches, fixtures)
      matches.count { |match| sync_match_safely(client, match, fixtures) }
    end

    def sync_match_safely(client, match, fixtures)
      sync_match(client, match, fixtures)
    rescue => e
      Rails.logger.error "Failed to sync odds for match #{match.id}: #{e.message}"
      false
    end

    def current_season
      today = Date.current
      today.month >= 8 ? today.year : today.year - 1
    end

    def fetch_fixtures(client)
      start_date = @gameweek.start_time.beginning_of_day
      end_date = (@gameweek.end_time || @gameweek.start_time + 4.days).end_of_day

      client.fixtures(league_id: PREMIER_LEAGUE_ID, season: @season, from: start_date, to: end_date)
    end

    def sync_match(client, match, fixtures)
      fixture = find_matching_fixture(match, fixtures)
      return log_no_fixture(match) unless fixture

      fixture_id = fixture.dig("fixture", "id")
      log_fixture_link(match, fixture_id)

      update_match_xg(client, match, fixture_id)
    end

    def log_no_fixture(match)
      Rails.logger.warn "No API-Football fixture found for #{match.home_team.name} vs #{match.away_team.name}"
      false
    end

    def log_fixture_link(match, fixture_id)
      Rails.logger.info "Linked #{match.home_team.short_name} vs #{match.away_team.short_name} to fixture #{fixture_id}"
    end

    def update_match_xg(client, match, fixture_id)
      odds_data = client.odds(fixture_id: fixture_id)
      return log_no_odds(fixture_id) unless odds_data&.any?

      home_xg, away_xg = ExpectedGoalsCalculator.call(odds_data: odds_data)
      return log_no_xg(match) unless home_xg && away_xg

      save_match_xg(match, home_xg, away_xg)
    end

    def log_no_odds(fixture_id)
      Rails.logger.warn "No odds data for fixture #{fixture_id}"
      false
    end

    def log_no_xg(match)
      Rails.logger.warn "Could not calculate xG for #{match.home_team.short_name} vs #{match.away_team.short_name}"
      false
    end

    def save_match_xg(match, home_xg, away_xg)
      match.update!(home_team_expected_goals: home_xg, away_team_expected_goals: away_xg)
      Rails.logger.info "#{match.home_team.short_name} vs #{match.away_team.short_name}: xG #{home_xg} - #{away_xg}"
      true
    end

    def find_matching_fixture(match, fixtures)
      home_id = match.home_team.api_football_id
      away_id = match.away_team.api_football_id
      return nil unless home_id && away_id

      fixtures.find { |f| f.dig("teams", "home", "id") == home_id && f.dig("teams", "away", "id") == away_id }
    end
  end
end
