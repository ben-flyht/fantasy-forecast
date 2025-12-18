require "net/http"
require "json"

module Fpl
  class SyncGameweeks < ApplicationService
    FPL_API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"
    FIXTURES_API_URL = "https://fantasy.premierleague.com/api/fixtures/"

    def call
      Rails.logger.info "Starting FPL gameweek sync..."
      data = fetch_api_data(FPL_API_URL)
      return false unless data

      sync_gameweeks(data["events"])
      sync_fixtures
      log_completion
      true
    rescue => e
      Rails.logger.error "FPL gameweek sync failed: #{e.message}"
      false
    end

    private

    def sync_fixtures
      fixtures_data = fetch_api_data(FIXTURES_API_URL)
      fixtures_data ? sync_matches(fixtures_data) : Rails.logger.warn("Could not fetch fixtures data")
    end

    def log_completion
      Rails.logger.info "FPL gameweek sync completed. Total gameweeks: #{Gameweek.count}, Total matches: #{Match.count}"
    end

    def fetch_api_data(url)
      uri = URI(url)
      response = make_http_request(uri)
      parse_response(response, url)
    end

    def make_http_request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"
        http.request(request)
      end
    end

    def parse_response(response, url)
      return JSON.parse(response.body) if response.code == "200"

      Rails.logger.error "FPL API returned #{response.code} for #{url}"
      nil
    end

    def sync_matches(fixtures_data)
      Rails.logger.info "Syncing matches..."
      counts = { success: 0, skip: 0, error: 0 }
      fixtures_data.each { |fixture| sync_match(fixture, counts) }
      Rails.logger.info "Match sync results: #{counts[:success]} synced, #{counts[:skip]} skipped, #{counts[:error]} errors"
    end

    def sync_match(fixture, counts)
      match_data = extract_match_data(fixture)
      return counts[:skip] += 1 unless match_data

      match = Match.find_or_initialize_by(fpl_id: fixture["id"])
      match.assign_attributes(match_data)
      save_match(match, fixture, counts)
    rescue => e
      Rails.logger.error "Exception syncing fixture #{fixture['id']}: #{e.message}"
      counts[:error] += 1
    end

    def extract_match_data(fixture)
      return nil unless fixture_valid?(fixture)

      gameweek = Gameweek.find_by(fpl_id: fixture["event"])
      home_team = Team.find_by(fpl_id: fixture["team_h"])
      away_team = Team.find_by(fpl_id: fixture["team_a"])
      return nil unless gameweek && home_team && away_team

      { home_team: home_team, away_team: away_team, gameweek: gameweek }
    end

    def fixture_valid?(fixture)
      fixture["id"] && fixture["event"] && fixture["team_h"] && fixture["team_a"]
    end

    def save_match(match, fixture, counts)
      if match.save
        counts[:success] += 1
      else
        Rails.logger.error "Failed to sync match #{fixture['id']}: #{match.errors.full_messages.join(', ')}"
        counts[:error] += 1
      end
    end

    def sync_gameweeks(events)
      Gameweek.update_all(is_current: false, is_next: false)
      events.each_with_index { |event, index| sync_gameweek(event, events, index) }
    end

    def sync_gameweek(event, events, index)
      return unless gameweek_valid?(event)

      start_time = parse_deadline(event["deadline_time"])
      return unless start_time

      gameweek = Gameweek.find_or_initialize_by(fpl_id: event["id"])
      gameweek.assign_attributes(gameweek_attributes(event, events, index, start_time))
      log_gameweek_result(gameweek, event)
    end

    def gameweek_valid?(event)
      event["id"].present? && event["name"].present? && event["deadline_time"].present?
    end

    def parse_deadline(deadline_time)
      Time.parse(deadline_time)
    rescue ArgumentError
      Rails.logger.warn "Invalid deadline_time: #{deadline_time}"
      nil
    end

    def gameweek_attributes(event, events, index, start_time)
      {
        name: event["name"], start_time: start_time, end_time: calculate_end_time(events, index),
        is_current: event["is_current"] || false, is_next: event["is_next"] || false,
        is_finished: event["finished"] || false
      }
    end

    def calculate_end_time(events, index)
      return nil if index >= events.length - 1

      next_deadline = events[index + 1]["deadline_time"]
      Time.parse(next_deadline) - 1.second if next_deadline.present?
    rescue ArgumentError
      nil
    end

    def log_gameweek_result(gameweek, event)
      if gameweek.save
        Rails.logger.debug "Synced gameweek: #{event['name']}"
      else
        Rails.logger.warn "Failed to sync gameweek #{event['name']}: #{gameweek.errors.full_messages.join(', ')}"
      end
    end
  end
end
