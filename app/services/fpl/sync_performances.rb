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

      # Process each player's performance data
      elements = gameweek_data["elements"] || []
      synced_count = 0

      elements.each do |element|
        fpl_id = element["id"]
        player = Player.find_by(fpl_id: fpl_id)
        next unless player

        stats = element["stats"] || {}

        # Save all statistics (features + target variable)
        if sync_statistics_for_player(player, gameweek, stats)
          synced_count += 1
          total_points = stats["total_points"] || 0
          Rails.logger.debug "Synced statistics for #{player.full_name} - GW#{gameweek.fpl_id}: #{total_points} pts"

          # Also create/update Performance record for backward compatibility
          sync_performance_record(player, gameweek, stats)
        end
      end

      Rails.logger.info "FPL performance sync completed for gameweek #{gameweek.name}. Synced: #{synced_count} performances"
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

    def sync_statistics_for_player(player, gameweek, stats)
      stat_count = 0

      STAT_TYPES.each do |stat_type|
        value = stats[stat_type]
        next if value.nil?

        # Convert string values to decimals
        value = value.to_f if value.is_a?(String)

        statistic = Statistic.find_or_initialize_by(
          player: player,
          gameweek: gameweek,
          type: stat_type
        )

        statistic.value = value

        if statistic.save
          stat_count += 1
        else
          Rails.logger.warn "Failed to save statistic #{stat_type} for #{player.full_name}: #{statistic.errors.full_messages.join(', ')}"
        end
      end

      stat_count > 0
    rescue => e
      Rails.logger.error "Failed to sync statistics for #{player.full_name}: #{e.message}"
      false
    end

    def sync_performance_record(player, gameweek, stats)
      # Maintain Performance record for backward compatibility
      gameweek_score = stats["total_points"] || 0

      performance = Performance.find_or_initialize_by(player: player, gameweek: gameweek)
      performance.assign_attributes(
        gameweek_score: gameweek_score,
        team: player.team
      )

      unless performance.save
        Rails.logger.warn "Failed to sync performance record for #{player.full_name}: #{performance.errors.full_messages.join(', ')}"
      end
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
