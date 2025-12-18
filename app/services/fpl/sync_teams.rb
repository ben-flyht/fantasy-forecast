require "net/http"
require "json"

module Fpl
  class SyncTeams < ApplicationService
    FPL_API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"

    def call
      Rails.logger.info "Starting FPL teams sync..."
      data = fetch_fpl_data
      return false unless data

      sync_teams(data["teams"])
      log_completion
      true
    rescue => e
      log_error(e)
      false
    end

    private

    def sync_teams(teams_data)
      teams_data.each { |team_data| sync_team(team_data) }
    end

    def sync_team(team_data)
      team = Team.find_or_initialize_by(fpl_id: team_data["id"])
      team.assign_attributes(team_attributes(team_data))
      log_team_result(team, team_data)
    end

    def team_attributes(data)
      { name: data["name"], short_name: data["short_name"], code: data["code"] }
    end

    def log_team_result(team, data)
      if team.save
        Rails.logger.info "Synced team: #{team.name} (#{team.short_name})"
      else
        Rails.logger.error "Failed to sync team #{data['name']}: #{team.errors.full_messages.join(', ')}"
      end
    end

    def log_completion
      Rails.logger.info "Teams sync completed. Total teams: #{Team.count}"
    end

    def fetch_fpl_data
      uri = URI(FPL_API_URL)
      response = make_http_request(uri)
      parse_response(response)
    end

    def make_http_request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"
        http.request(request)
      end
    end

    def parse_response(response)
      return JSON.parse(response.body) if response.code == "200"

      Rails.logger.error "FPL API returned #{response.code}: #{response.message}"
      nil
    end

    def log_error(error)
      Rails.logger.error "Error syncing teams: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
    end
  end
end
