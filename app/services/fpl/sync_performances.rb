require "net/http"
require "json"

module Fpl
  class SyncPerformances < ApplicationService
    FPL_LIVE_URL = "https://fantasy.premierleague.com/api/event/"

    STAT_TYPES = %w[
      total_points minutes goals_scored assists clean_sheets goals_conceded own_goals
      penalties_saved penalties_missed yellow_cards red_cards saves bonus bps
      influence creativity threat ict_index starts expected_goals expected_assists
      expected_goal_involvements expected_goals_conceded clearances_blocks_interceptions
      recoveries tackles defensive_contribution
    ].freeze

    def initialize(gameweek_id = nil)
      @gameweek_id = gameweek_id
    end

    def call
      Rails.logger.info "Starting FPL performance sync..."
      gameweek = find_gameweek
      return false unless gameweek

      sync_gameweek_data(gameweek)
    rescue => e
      Rails.logger.error "FPL performance sync failed: #{e.message}"
      false
    end

    private

    def find_gameweek
      gameweek = @gameweek_id ? Gameweek.find_by(fpl_id: @gameweek_id) : default_gameweek
      return log_no_gameweek unless gameweek

      log_gameweek_info(gameweek)
      gameweek
    end

    def default_gameweek
      Gameweek.current_gameweek || Gameweek.finished.ordered.last
    end

    def log_no_gameweek
      Rails.logger.error "No current or finished gameweek found for sync"
      nil
    end

    def log_gameweek_info(gameweek)
      status = gameweek.is_finished? ? "finished" : "in progress"
      Rails.logger.info "Syncing performances for gameweek: #{gameweek.name} (#{status})"
    end

    def sync_gameweek_data(gameweek)
      gameweek_data = fetch_gameweek_live_data(gameweek.fpl_id)
      return false unless gameweek_data

      elements = gameweek_data["elements"] || []
      players_by_fpl_id = load_players(elements)

      sync_and_log(gameweek, elements, players_by_fpl_id)
    end

    def load_players(elements)
      fpl_ids = elements.map { |e| e["id"] }
      Player.where(fpl_id: fpl_ids).index_by(&:fpl_id)
    end

    def sync_and_log(gameweek, elements, players_by_fpl_id)
      stats_count = sync_all_statistics(gameweek, elements, players_by_fpl_id)
      perf_count = sync_all_performances(gameweek, elements, players_by_fpl_id)
      log_completion(gameweek, stats_count, perf_count)
      true
    end

    def log_completion(gameweek, stats_count, perf_count)
      Rails.logger.info "FPL performance sync completed for gameweek #{gameweek.name}. " \
                        "Statistics: #{stats_count}, Performances: #{perf_count}"
    end

    def sync_all_statistics(gameweek, elements, players_by_fpl_id)
      statistics_data = build_statistics_data(gameweek, elements, players_by_fpl_id)
      return 0 if statistics_data.empty?

      Statistic.upsert_all(statistics_data, unique_by: %i[player_id gameweek_id type])
      statistics_data.size
    end

    def build_statistics_data(gameweek, elements, players_by_fpl_id)
      now = Time.current
      elements.flat_map { |el| element_statistics(el, gameweek, players_by_fpl_id, now) }
    end

    def element_statistics(element, gameweek, players_by_fpl_id, now)
      player = players_by_fpl_id[element["id"]]
      return [] unless player

      stats = element["stats"] || {}
      STAT_TYPES.filter_map { |type| build_stat_record(player, gameweek, type, stats[type], now) }
    end

    def build_stat_record(player, gameweek, type, value, now)
      return nil if value.nil?

      { player_id: player.id, gameweek_id: gameweek.id, type: type,
        value: value.to_f, created_at: now, updated_at: now }
    end

    def sync_all_performances(gameweek, elements, players_by_fpl_id)
      performance_data = build_performance_data(gameweek, elements, players_by_fpl_id)
      return 0 if performance_data.empty?

      Performance.upsert_all(performance_data, unique_by: %i[player_id gameweek_id])
      performance_data.size
    end

    def build_performance_data(gameweek, elements, players_by_fpl_id)
      now = Time.current
      elements.filter_map { |el| build_performance_record(el, gameweek, players_by_fpl_id, now) }
    end

    def build_performance_record(element, gameweek, players_by_fpl_id, now)
      player = players_by_fpl_id[element["id"]]
      return nil unless player

      { player_id: player.id, gameweek_id: gameweek.id, team_id: player.team_id,
        gameweek_score: element.dig("stats", "total_points") || 0, created_at: now, updated_at: now }
    end

    def fetch_gameweek_live_data(gameweek_id)
      uri = URI("#{FPL_LIVE_URL}#{gameweek_id}/live/")
      response = make_http_request(uri)
      parse_response(response, gameweek_id)
    rescue => e
      Rails.logger.error "Failed to fetch live data for gameweek #{gameweek_id}: #{e.message}"
      nil
    end

    def make_http_request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"
        http.request(request)
      end
    end

    def parse_response(response, gameweek_id)
      return JSON.parse(response.body) if response.code == "200"

      Rails.logger.error "FPL Live API returned #{response.code} for gameweek #{gameweek_id}: #{response.message}"
      nil
    end
  end
end
