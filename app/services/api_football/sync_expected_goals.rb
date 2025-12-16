module ApiFootball
  class SyncExpectedGoals
    PREMIER_LEAGUE_ID = 39

    def self.call(gameweek: nil, season: nil)
      new(gameweek: gameweek, season: season).call
    end

    def initialize(gameweek: nil, season: nil)
      @gameweek = gameweek || Gameweek.next_gameweek || Gameweek.current_gameweek
      @season = season || current_season
    end

    def call
      return false unless @gameweek

      Rails.logger.info "Syncing API-Football expected goals for #{@gameweek.name}..."

      client = Client.new
      fixtures = fetch_fixtures(client)

      if fixtures.nil? || fixtures.empty?
        Rails.logger.warn "No fixtures found from API-Football"
        return false
      end

      Rails.logger.info "Found #{fixtures.size} fixtures from API-Football"

      matches = Match.includes(:home_team, :away_team).where(gameweek: @gameweek)
      synced_count = 0

      matches.each do |match|
        if sync_match(client, match, fixtures)
          synced_count += 1
        end
      rescue => e
        Rails.logger.error "Failed to sync odds for match #{match.id}: #{e.message}"
      end

      Rails.logger.info "Synced expected goals for #{synced_count}/#{matches.count} matches"
      true
    rescue Client::Error => e
      Rails.logger.error "API-Football error: #{e.message}"
      false
    end

    private

    def current_season
      # API-Football uses the year the season started (e.g., 2024 for 2024/25)
      today = Date.current
      today.month >= 8 ? today.year : today.year - 1
    end

    def fetch_fixtures(client)
      start_date = @gameweek.start_time.beginning_of_day
      end_date = (@gameweek.end_time || @gameweek.start_time + 4.days).end_of_day

      client.fixtures(
        league_id: PREMIER_LEAGUE_ID,
        season: @season,
        from: start_date,
        to: end_date
      )
    end

    def sync_match(client, match, fixtures)
      fixture = find_matching_fixture(match, fixtures)

      unless fixture
        Rails.logger.warn "No API-Football fixture found for #{match.home_team.name} vs #{match.away_team.name}"
        return false
      end

      fixture_id = fixture.dig("fixture", "id")
      Rails.logger.info "Linked #{match.home_team.short_name} vs #{match.away_team.short_name} to fixture #{fixture_id}"

      odds_data = fetch_odds(client, fixture_id)

      unless odds_data&.any?
        Rails.logger.warn "No odds data for fixture #{fixture_id}"
        return false
      end

      home_xg, away_xg = ExpectedGoalsCalculator.call(odds_data: odds_data)

      unless home_xg && away_xg
        Rails.logger.warn "Could not calculate xG for #{match.home_team.short_name} vs #{match.away_team.short_name}"
        return false
      end

      match.update!(
        home_team_expected_goals: home_xg,
        away_team_expected_goals: away_xg
      )

      Rails.logger.info "#{match.home_team.short_name} vs #{match.away_team.short_name}: xG #{home_xg} - #{away_xg}"
      true
    end

    def find_matching_fixture(match, fixtures)
      home_id = match.home_team.api_football_id
      away_id = match.away_team.api_football_id
      return nil unless home_id && away_id

      fixtures.find do |fixture|
        fixture.dig("teams", "home", "id") == home_id &&
          fixture.dig("teams", "away", "id") == away_id
      end
    end

    def fetch_odds(client, fixture_id)
      client.odds(fixture_id: fixture_id)
    end
  end
end
