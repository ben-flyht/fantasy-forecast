require "net/http"
require "json"

module Fpl
  class SyncPerformances
    FPL_LIVE_URL = "https://fantasy.premierleague.com/api/event/"

    def self.call(gameweek_id = nil)
      new.call(gameweek_id)
    end

    def call(gameweek_id = nil)
      Rails.logger.info "Starting FPL performance sync..."

      # Use latest finished gameweek if none specified (performances only available for finished gameweeks)
      gameweek = if gameweek_id
        Gameweek.find_by(fpl_id: gameweek_id)
      else
        Gameweek.finished.ordered.last
      end

      unless gameweek
        Rails.logger.error "No finished gameweek found for sync"
        return false
      end

      Rails.logger.info "Syncing performances for gameweek: #{gameweek.name}"

      # Fetch all player performance data for this gameweek in a single API call
      gameweek_data = fetch_gameweek_live_data(gameweek.fpl_id)
      return false unless gameweek_data

      # Process each player's performance data
      elements = gameweek_data["elements"] || []
      synced_count = 0

      elements.each do |element|
        fpl_id = element["id"]
        player = Player.find_by(fpl_id: fpl_id)
        next unless player

        gameweek_score = element.dig("stats", "total_points") || 0

        performance_attributes = {
          gameweek_score: gameweek_score,
          team: player.team
        }

        performance = Performance.find_or_initialize_by(player: player, gameweek: gameweek)
        performance.assign_attributes(performance_attributes)

        if performance.save
          synced_count += 1
          Rails.logger.debug "Synced performance for #{player.full_name} - GW#{gameweek.fpl_id}: #{gameweek_score} pts"
        else
          Rails.logger.warn "Failed to sync performance for #{player.full_name}: #{performance.errors.full_messages.join(', ')}"
        end
      end

      Rails.logger.info "FPL performance sync completed for gameweek #{gameweek.name}. Synced: #{synced_count} performances"
      true
    rescue => e
      Rails.logger.error "FPL performance sync failed: #{e.message}"
      false
    end

    private

    def fetch_gameweek_live_data(gameweek_id)
      uri = URI("#{FPL_LIVE_URL}#{gameweek_id}/live/")

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"

        response = http.request(request)

        if response.code == "200"
          JSON.parse(response.body)
        else
          Rails.logger.error "FPL Live API returned #{response.code} for gameweek #{gameweek_id}: #{response.message}"
          nil
        end
      end
    rescue => e
      Rails.logger.error "Failed to fetch live data for gameweek #{gameweek_id}: #{e.message}"
      nil
    end
  end
end
