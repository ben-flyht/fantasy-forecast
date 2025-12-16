module ApiFootball
  class SyncTeams
    PREMIER_LEAGUE_ID = 39

    # Mapping from API-Football short codes to FPL short codes
    # where they differ
    API_FOOTBALL_TO_FPL_CODE = {
      "AST" => "AVL",  # Aston Villa
      "BRI" => "BHA",  # Brighton
      "NOT" => "NFO",  # Nottingham Forest
      "WES" => "WHU"   # West Ham
    }.freeze

    def self.call(season: nil)
      new(season: season).call
    end

    def initialize(season: nil)
      @season = season || current_season
    end

    def call
      Rails.logger.info "Syncing API-Football team IDs for season #{@season}..."

      client = Client.new
      api_teams = client.teams(season: @season)

      if api_teams.nil? || api_teams.empty?
        Rails.logger.warn "No teams found from API-Football"
        return false
      end

      Rails.logger.info "Found #{api_teams.size} teams from API-Football"

      matched = 0
      unmatched = []

      api_teams.each do |api_team|
        team_data = api_team["team"]
        api_football_id = team_data["id"]
        api_code = team_data["code"]
        api_name = team_data["name"]

        # Try to match by short_name (with code mapping)
        fpl_code = API_FOOTBALL_TO_FPL_CODE[api_code] || api_code
        team = Team.find_by(short_name: fpl_code)

        if team
          team.update!(api_football_id: api_football_id)
          Rails.logger.info "Matched #{team.name} (#{team.short_name}) -> API-Football ID #{api_football_id}"
          matched += 1
        else
          unmatched << { name: api_name, code: api_code, id: api_football_id }
        end
      end

      if unmatched.any?
        Rails.logger.warn "Unmatched API-Football teams:"
        unmatched.each do |t|
          Rails.logger.warn "  #{t[:name]} (#{t[:code]}) - ID: #{t[:id]}"
        end
      end

      Rails.logger.info "Synced #{matched}/#{Team.count} teams"
      true
    rescue Client::Error => e
      Rails.logger.error "API-Football error: #{e.message}"
      false
    end

    private

    def current_season
      today = Date.current
      today.month >= 8 ? today.year : today.year - 1
    end
  end
end
