require "net/http"
require "json"

module Fpl
  class SyncTeams
    FPL_API_URL = "https://fantasy.premierleague.com/api/bootstrap-static/"

    def self.call
      new.call
    end

    def call
      Rails.logger.info "Starting FPL teams sync..."

      data = fetch_fpl_data
      return false unless data

      teams_data = data["teams"]

      teams_data.each do |team_data|
        team = Team.find_or_initialize_by(fpl_id: team_data["id"])

        team.assign_attributes(
          name: team_data["name"],
          short_name: team_data["short_name"]
        )

        if team.save
          Rails.logger.info "Synced team: #{team.name} (#{team.short_name})"
        else
          Rails.logger.error "Failed to sync team #{team_data['name']}: #{team.errors.full_messages.join(', ')}"
        end
      end

      Rails.logger.info "Teams sync completed. Total teams: #{Team.count}"
      true
    rescue => e
      Rails.logger.error "Error syncing teams: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end

    private

    def fetch_fpl_data
      uri = URI(FPL_API_URL)

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"

        response = http.request(request)

        if response.code == "200"
          JSON.parse(response.body)
        else
          Rails.logger.error "FPL API returned #{response.code}: #{response.message}"
          nil
        end
      end
    end
  end
end
