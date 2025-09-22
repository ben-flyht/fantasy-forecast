require "net/http"
require "json"

module Fpl
  class SyncMatches
    def self.call
      new.call
    end

    def call
      sync_matches
    end

    private

    def sync_matches
      response = fetch_fixtures_data
      return false unless response

      fixtures = parse_fixtures(response)
      return false unless fixtures

      ActiveRecord::Base.transaction do
        fixtures.each do |fixture|
          sync_match(fixture)
        end
      end

      true
    rescue StandardError => e
      Rails.logger.error "Error syncing matches: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end

    def fetch_fixtures_data
      uri = URI("https://fantasy.premierleague.com/api/fixtures/")
      response = Net::HTTP.get_response(uri)

      if response.code == "200"
        response.body
      else
        Rails.logger.error "Failed to fetch fixtures data: HTTP #{response.code}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Error fetching fixtures data: #{e.message}"
      nil
    end

    def parse_fixtures(response_body)
      JSON.parse(response_body)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse fixtures JSON: #{e.message}"
      nil
    end

    def sync_match(fixture_data)
      return unless fixture_data["event"] # Skip if no gameweek assigned

      gameweek = Gameweek.find_by(fpl_id: fixture_data["event"])
      return unless gameweek # Skip if gameweek doesn't exist

      home_team = Team.find_by(fpl_id: fixture_data["team_h"])
      away_team = Team.find_by(fpl_id: fixture_data["team_a"])

      return unless home_team && away_team # Skip if teams don't exist

      match = Match.find_or_initialize_by(fpl_id: fixture_data["id"])
      match.assign_attributes(
        home_team: home_team,
        away_team: away_team,
        gameweek: gameweek
      )
      match.save!
    rescue StandardError => e
      Rails.logger.warn "Failed to sync match #{fixture_data['id']}: #{e.message}"
    end
  end
end
