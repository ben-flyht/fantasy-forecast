module Fpl
  # The single scheduled job. Every step is idempotent and self-skipping, so it
  # is safe to run hourly: syncs upsert, and forecasts only generate when there is
  # a next gameweek to forecast. A season rollover (detected by a changed team
  # list) wipes last season first so the fresh data isn't blended with the old.
  #
  # Every step reads from FPL's own API and nowhere else.
  #
  # Gameweeks go first because three of the syncs after them file what they find
  # against whichever gameweek is current. Read before FPL's rollover has been
  # picked up, this week's readings land on last week's gameweek: a week's football
  # recorded as evidence that was available before it was played.
  class HourlyPipeline < ApplicationService
    SYNCS = [
      SyncGameweeks,       # gameweeks + fixtures
      SyncPlayers,         # teams, players, availability + snapshot stats
      SyncPayloads,        # everything FPL publishes, kept verbatim
      SyncPerformances,    # current gameweek's live scores
      SyncPlayerHistories  # last season's totals (once per player, then skipped)
    ].freeze

    def call
      reset_if_new_season

      failures = syncs.reject(&:call).map { |sync| sync.class.name }
      failures << "forecasts" unless generate_forecasts
      return true if failures.empty?

      Rails.logger.error "Hourly pipeline finished with failures: #{failures.join(', ')}"
      false
    end

    private

    # One Api between them, so FPL is asked for each publication once and every
    # sync in the run reads the same one.
    def syncs
      SYNCS.map { |sync| sync.new(api: api) }
    end

    def api
      @api ||= Api.new
    end

    def reset_if_new_season
      return unless Fpl::NewSeasonDetector.call(api: api)

      Rails.logger.warn "New season detected (team list changed). Wiping last season for a fresh start."
      Fpl::ResetSeason.call
    end

    # Written down rather than worked out while somebody watches a page, so the
    # week's prediction still exists on Sunday when it can be marked.
    def generate_forecasts
      gameweek = Gameweek.next_gameweek
      return nothing_to_forecast unless gameweek

      [ WeeklyForecast.call(gameweek: gameweek), SeasonForecast.call(gameweek: gameweek) ].all?
    end

    # Pre-season FPL names no next gameweek. Having nothing to forecast is a quiet
    # summer, not a fault, and must not be reported as one.
    def nothing_to_forecast
      Rails.logger.info "No next gameweek, skipping forecast generation."
      true
    end
  end
end
