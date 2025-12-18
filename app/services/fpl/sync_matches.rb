require "net/http"
require "json"

module Fpl
  class SyncMatches < ApplicationService
    FPL_FIXTURES_URL = "https://fantasy.premierleague.com/api/fixtures/"

    def call
      sync_matches
    end

    private

    def sync_matches
      fixtures = fetch_and_parse_fixtures
      return false unless fixtures

      process_fixtures(fixtures)
    rescue StandardError => e
      log_error(e)
      false
    end

    def fetch_and_parse_fixtures
      response = fetch_fixtures_data
      response ? parse_fixtures(response) : nil
    end

    def process_fixtures(fixtures)
      ActiveRecord::Base.transaction do
        fixtures.each { |fixture| sync_match(fixture) }
      end
      true
    end

    def fetch_fixtures_data
      uri = URI(FPL_FIXTURES_URL)
      response = Net::HTTP.get_response(uri)
      handle_response(response)
    rescue StandardError => e
      Rails.logger.error "Error fetching fixtures data: #{e.message}"
      nil
    end

    def handle_response(response)
      return response.body if response.code == "200"

      Rails.logger.error "Failed to fetch fixtures data: HTTP #{response.code}"
      nil
    end

    def parse_fixtures(response_body)
      JSON.parse(response_body)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse fixtures JSON: #{e.message}"
      nil
    end

    def sync_match(fixture_data)
      match_data = extract_match_data(fixture_data)
      return unless match_data

      save_match(fixture_data, match_data)
    rescue StandardError => e
      Rails.logger.warn "Failed to sync match #{fixture_data['id']}: #{e.message}"
    end

    def extract_match_data(fixture_data)
      return nil unless fixture_data["event"]

      gameweek = Gameweek.find_by(fpl_id: fixture_data["event"])
      home_team = Team.find_by(fpl_id: fixture_data["team_h"])
      away_team = Team.find_by(fpl_id: fixture_data["team_a"])
      return nil unless gameweek && home_team && away_team

      { gameweek: gameweek, home_team: home_team, away_team: away_team }
    end

    def save_match(fixture_data, match_data)
      match = Match.find_or_initialize_by(fpl_id: fixture_data["id"])
      match.assign_attributes(match_data)
      match.save!
    end

    def log_error(error)
      Rails.logger.error "Error syncing matches: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
    end
  end
end
