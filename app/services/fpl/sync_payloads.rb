require "net/http"
require "json"

module Fpl
  # Stores everything FPL publishes, exactly as they publish it, once per
  # gameweek: every player, team, gameweek and fixture.
  #
  # The curated syncs pick out the fields the ranking reads today and cast them to
  # numbers. This one keeps the whole thing, so tomorrow's strategy can reach for a
  # field nobody thought to map without waiting a season for the history to build.
  #
  # Rows are replaced in place through the week, so a gameweek holds the most
  # recent state rather than an hourly trail. Anything FPL stops publishing, a
  # player who leaves the league mid-season, is removed from the current gameweek
  # so the record keeps matching the source. Finished gameweeks are never touched.
  class SyncPayloads < ApplicationService
    BOOTSTRAP_URL = "https://fantasy.premierleague.com/api/bootstrap-static/".freeze
    FIXTURES_URL = "https://fantasy.premierleague.com/api/fixtures/".freeze

    # The bootstrap collection each kind is drawn from.
    BOOTSTRAP_KINDS = {
      Payload::ELEMENT => "elements",
      Payload::TEAM => "teams",
      Payload::EVENT => "events"
    }.freeze

    def call
      gameweek = snapshot_gameweek
      return log_no_gameweek unless gameweek

      bootstrap = fetch(BOOTSTRAP_URL)
      return false unless bootstrap

      counts = store_all(bootstrap, gameweek)
      Rails.logger.info "FPL payloads for gameweek #{gameweek.fpl_id}: #{counts.map { |k, n| "#{n} #{k}s" }.join(', ')}"
      counts
    rescue => e
      Rails.logger.error "FPL payload sync failed: #{e.message}"
      false
    end

    private

    # Pre-season there is no current gameweek, so the upcoming one carries the
    # record, exactly as the other syncs do.
    def snapshot_gameweek
      Gameweek.current_gameweek || Gameweek.next_gameweek
    end

    def store_all(bootstrap, gameweek)
      counts = BOOTSTRAP_KINDS.to_h do |kind, collection|
        [ kind, store(kind, bootstrap[collection], gameweek) ]
      end
      counts.merge(Payload::FIXTURE => store(Payload::FIXTURE, fetch(FIXTURES_URL), gameweek))
    end

    # Upsert what FPL sent, then drop anything it no longer sends, so what we hold
    # is the payload rather than everything we have ever seen.
    def store(kind, records, gameweek)
      return 0 if records.blank?

      rows = records.filter_map { |record| row_for(kind, record, gameweek) }
      return 0 if rows.empty?

      Payload.upsert_all(rows, unique_by: %i[kind fpl_id gameweek_id])
      remove_departed(kind, rows.map { |row| row[:fpl_id] }, gameweek)
      rows.size
    end

    def row_for(kind, record, gameweek)
      fpl_id = record["id"]
      return nil if fpl_id.nil?

      now = Time.current
      { kind: kind, fpl_id: fpl_id, gameweek_id: gameweek.id, data: record,
        created_at: now, updated_at: now }
    end

    def remove_departed(kind, present_ids, gameweek)
      departed = Payload.of_kind(kind).for_gameweek(gameweek).where.not(fpl_id: present_ids)
      count = departed.delete_all
      Rails.logger.info "Removed #{count} #{kind} payloads FPL no longer publishes" if count.positive?
      count
    end

    def log_no_gameweek
      Rails.logger.info "No gameweek to attach payloads to, skipping."
      false
    end

    def fetch(url)
      uri = URI(url)
      response = get(uri)
      return log_api_error(url, response) unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def get(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Fantasy Forecast App"
        http.request(request)
      end
    end

    def log_api_error(url, response)
      Rails.logger.error "FPL returned #{response.code} for #{url}"
      nil
    end
  end
end
