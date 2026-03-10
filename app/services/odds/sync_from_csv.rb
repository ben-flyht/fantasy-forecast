require "net/http"
require "csv"

module Odds
  class SyncFromCsv < ApplicationService
    BASE_URL = "https://www.football-data.co.uk/mmz4281/"
    LEAGUE = "E0" # Premier League

    # football-data.co.uk team names -> our Team.name values
    TEAM_NAME_MAP = {
      "Arsenal" => "Arsenal",
      "Aston Villa" => "Aston Villa",
      "Bournemouth" => "Bournemouth",
      "Brentford" => "Brentford",
      "Brighton" => "Brighton",
      "Burnley" => "Burnley",
      "Chelsea" => "Chelsea",
      "Crystal Palace" => "Crystal Palace",
      "Everton" => "Everton",
      "Fulham" => "Fulham",
      "Leeds" => "Leeds",
      "Liverpool" => "Liverpool",
      "Man City" => "Man City",
      "Man United" => "Man Utd",
      "Newcastle" => "Newcastle",
      "Nott'm Forest" => "Nott'm Forest",
      "Sunderland" => "Sunderland",
      "Tottenham" => "Spurs",
      "West Ham" => "West Ham",
      "Wolves" => "Wolves"
    }.freeze

    def initialize(season: nil)
      @season = season || current_season
    end

    def call
      csv_data = fetch_csv
      return { matched: 0, unmatched: 0, error: "Could not fetch CSV" } unless csv_data

      teams = Team.all.index_by(&:name)
      process_csv(csv_data, teams)
    end

    private

    def fetch_csv
      url = "#{BASE_URL}#{@season}/#{LEAGUE}.csv"
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        response.body.dup.force_encoding("UTF-8")
      else
        Rails.logger.error "Odds CSV fetch failed: #{response.code} from #{url}"
        nil
      end
    end

    def process_csv(csv_data, teams)
      results = CSV.parse(csv_data, headers: true).map { |row| update_match_odds(row, teams) }
      { matched: results.count(true), unmatched: results.count(false) }
    end

    def update_match_odds(row, teams)
      home_team = teams[TEAM_NAME_MAP[row["HomeTeam"]]]
      away_team = teams[TEAM_NAME_MAP[row["AwayTeam"]]]
      return false unless home_team && away_team

      odds = extract_odds(row)
      return false unless odds

      match = find_match(home_team, away_team)
      return false unless match

      match.update_columns(odds)
    end

    def find_match(home_team, away_team)
      Match.find_by(home_team: home_team, away_team: away_team)
    end

    def extract_odds(row)
      home = best_odds(row, %w[AvgH B365H PSH])
      draw = best_odds(row, %w[AvgD B365D PSD])
      away = best_odds(row, %w[AvgA B365A PSA])
      return nil unless home && draw && away

      { odds_home_win: home, odds_draw: draw, odds_away_win: away }
    end

    def best_odds(row, columns)
      columns.each do |col|
        value = row[col]&.to_f
        return value if value && value > 0
      end
      nil
    end

    def current_season
      today = Date.current
      year = today.month >= 7 ? today.year : today.year - 1
      format("%02d%02d", year % 100, (year + 1) % 100)
    end
  end
end
