require "net/http"
require "json"

module Fpl
  # Last season's totals for every player, from FPL's per-player summary endpoint.
  #
  # Before a ball is kicked FPL zeroes the season stats in bootstrap-static, so
  # the concepts that lean on recent scoring have nothing to read. Last season's
  # totals are the best cold-start stand-in and they live only on this endpoint,
  # one request per player.
  #
  # That makes this the most expensive sync we run, so it is deliberately
  # incremental: players whose totals are already stored are skipped. A re-run
  # costs almost nothing and an interrupted run picks up where it stopped.
  class SyncPlayerHistories < ApplicationService
    ELEMENT_SUMMARY_URL = "https://fantasy.premierleague.com/api/element-summary/".freeze

    # Statistic type => the key to read from FPL's past-season entry.
    STAT_TYPES = {
      "last_season_points" => "total_points",
      "last_season_minutes" => "minutes"
    }.freeze

    REQUEST_DELAY = 0.5 # seconds between requests, to stay a polite guest

    def initialize(delay: REQUEST_DELAY)
      @delay = delay
    end

    def call
      gameweek = snapshot_gameweek
      return false unless gameweek

      players = players_missing_history(gameweek)
      return log_nothing_to_do if players.empty?

      sync_players(players, gameweek)
    rescue => e
      Rails.logger.error "FPL player history sync failed: #{e.message}"
      false
    end

    private

    # Pre-season there is no current gameweek, but last season's totals are
    # exactly what the upcoming one needs, so attach them there.
    def snapshot_gameweek
      Gameweek.current_gameweek || Gameweek.next_gameweek
    end

    def players_missing_history(gameweek)
      already_synced = Statistic.where(gameweek: gameweek, type: STAT_TYPES.keys.first).select(:player_id)
      Player.where.not(id: already_synced).to_a
    end

    def sync_players(players, gameweek)
      Rails.logger.info "Syncing last-season history for #{players.size} players..."
      records = collect_records(players, gameweek)
      return log_nothing_to_do if records.empty?

      Statistic.upsert_all(records, unique_by: %i[player_id gameweek_id type])
      Rails.logger.info "Synced #{records.size} last-season statistics for gameweek #{gameweek.fpl_id}"
      true
    end

    def collect_records(players, gameweek)
      now = Time.current
      players.flat_map.with_index do |player, index|
        sleep(@delay) if index.positive? && @delay.positive?
        player_records(player, gameweek, now)
      end
    end

    def player_records(player, gameweek, now)
      season = latest_past_season(player)
      return [] if season.nil?

      STAT_TYPES.filter_map do |type, key|
        value = season[key]
        next if value.nil?

        { player_id: player.id, gameweek_id: gameweek.id, type: type,
          value: value.to_f, created_at: now, updated_at: now }
      end
    end

    # history_past runs oldest first, so the most recent season is last.
    def latest_past_season(player)
      summary = fetch_summary(player.fpl_id)
      summary && summary["history_past"]&.last
    end

    def fetch_summary(fpl_id)
      response = get(URI("#{ELEMENT_SUMMARY_URL}#{fpl_id}/"))
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue => e
      Rails.logger.warn "Could not fetch history for FPL player #{fpl_id}: #{e.message}"
      nil
    end

    def get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Mozilla/5.0"
        http.request(request)
      end
    end

    def log_nothing_to_do
      Rails.logger.info "No players need a last-season history sync."
      true
    end
  end
end
