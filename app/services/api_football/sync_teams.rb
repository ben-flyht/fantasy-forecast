module ApiFootball
  class SyncTeams < ApplicationService
    PREMIER_LEAGUE_ID = 39

    API_FOOTBALL_TO_FPL_CODE = {
      "AST" => "AVL",  # Aston Villa
      "BRI" => "BHA",  # Brighton
      "NOT" => "NFO",  # Nottingham Forest
      "WES" => "WHU"   # West Ham
    }.freeze

    def initialize(season: nil)
      @season = season || current_season
    end

    def call
      Rails.logger.info "Syncing API-Football team IDs for season #{@season}..."

      api_teams = fetch_api_teams
      return log_no_teams if api_teams.nil? || api_teams.empty?

      sync_all_teams(api_teams)
    rescue Client::Error => e
      Rails.logger.error "API-Football error: #{e.message}"
      false
    end

    private

    def fetch_api_teams
      client = Client.new
      client.teams(season: @season)
    end

    def log_no_teams
      Rails.logger.warn "No teams found from API-Football"
      false
    end

    def sync_all_teams(api_teams)
      Rails.logger.info "Found #{api_teams.size} teams from API-Football"

      results = process_teams(api_teams)
      log_results(results)
      true
    end

    def process_teams(api_teams)
      matched = 0
      unmatched = []

      api_teams.each do |api_team|
        result = sync_team(api_team)
        result ? matched += 1 : unmatched << result_data(api_team)
      end

      { matched: matched, unmatched: unmatched }
    end

    def sync_team(api_team)
      team_data = api_team["team"]
      team = find_matching_team(team_data)
      return false unless team

      update_team(team, team_data)
      true
    end

    def find_matching_team(team_data)
      api_code = team_data["code"]
      fpl_code = API_FOOTBALL_TO_FPL_CODE[api_code] || api_code
      Team.find_by(short_name: fpl_code)
    end

    def update_team(team, team_data)
      api_football_id = team_data["id"]
      team.update!(api_football_id: api_football_id)
      Rails.logger.info "Matched #{team.name} (#{team.short_name}) -> API-Football ID #{api_football_id}"
    end

    def result_data(api_team)
      team_data = api_team["team"]
      { name: team_data["name"], code: team_data["code"], id: team_data["id"] }
    end

    def log_results(results)
      log_unmatched(results[:unmatched]) if results[:unmatched].any?
      Rails.logger.info "Synced #{results[:matched]}/#{Team.count} teams"
    end

    def log_unmatched(unmatched)
      Rails.logger.warn "Unmatched API-Football teams:"
      unmatched.each { |t| Rails.logger.warn "  #{t[:name]} (#{t[:code]}) - ID: #{t[:id]}" }
    end

    def current_season
      today = Date.current
      today.month >= 8 ? today.year : today.year - 1
    end
  end
end
