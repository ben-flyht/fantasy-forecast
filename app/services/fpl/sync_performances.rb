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

      # Use current or latest finished gameweek if none specified
      # This allows live scoring during in-progress gameweeks
      gameweek = if gameweek_id
        Gameweek.find_by(fpl_id: gameweek_id)
      else
        Gameweek.current_gameweek || Gameweek.finished.ordered.last
      end

      unless gameweek
        Rails.logger.error "No current or finished gameweek found for sync"
        return false
      end

      Rails.logger.info "Syncing performances for gameweek: #{gameweek.name} (#{gameweek.is_finished? ? 'finished' : 'in progress'})"

      # Fetch all player performance data for this gameweek in a single API call
      gameweek_data = fetch_gameweek_live_data(gameweek.fpl_id)
      return false unless gameweek_data

      elements = gameweek_data["elements"] || []

      # Pre-load all players in one query
      fpl_ids = elements.map { |e| e["id"] }
      players_by_fpl_id = Player.where(fpl_id: fpl_ids).index_by(&:fpl_id)

      # Bulk upsert statistics and performances
      statistics_count = sync_all_statistics(gameweek, elements, players_by_fpl_id)
      performance_count = sync_all_performances(gameweek, elements, players_by_fpl_id)

      Rails.logger.info "FPL performance sync completed for gameweek #{gameweek.name}. " \
                        "Statistics: #{statistics_count}, Performances: #{performance_count}"
      true
    rescue => e
      Rails.logger.error "FPL performance sync failed: #{e.message}"
      false
    end

    private

    # All stat types to sync from the FPL API stats object
    STAT_TYPES = %w[
      total_points
      minutes
      goals_scored
      assists
      clean_sheets
      goals_conceded
      own_goals
      penalties_saved
      penalties_missed
      yellow_cards
      red_cards
      saves
      bonus
      bps
      influence
      creativity
      threat
      ict_index
      starts
      expected_goals
      expected_assists
      expected_goal_involvements
      expected_goals_conceded
      clearances_blocks_interceptions
      recoveries
      tackles
      defensive_contribution
    ].freeze

    def sync_all_statistics(gameweek, elements, players_by_fpl_id)
      now = Time.current
      statistics_data = []

      elements.each do |element|
        player = players_by_fpl_id[element["id"]]
        next unless player

        stats = element["stats"] || {}

        STAT_TYPES.each do |stat_type|
          value = stats[stat_type]
          next if value.nil?

          statistics_data << {
            player_id: player.id,
            gameweek_id: gameweek.id,
            type: stat_type,
            value: value.to_f,
            created_at: now,
            updated_at: now
          }
        end
      end

      return 0 if statistics_data.empty?

      Statistic.upsert_all(
        statistics_data,
        unique_by: %i[player_id gameweek_id type]
      )

      statistics_data.size
    end

    def sync_all_performances(gameweek, elements, players_by_fpl_id)
      now = Time.current

      performance_data = elements.filter_map do |element|
        player = players_by_fpl_id[element["id"]]
        next unless player

        {
          player_id: player.id,
          gameweek_id: gameweek.id,
          gameweek_score: element.dig("stats", "total_points") || 0,
          team_id: player.team_id,
          created_at: now,
          updated_at: now
        }
      end

      return 0 if performance_data.empty?

      Performance.upsert_all(
        performance_data,
        unique_by: %i[player_id gameweek_id]
      )

      performance_data.size
    end

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
