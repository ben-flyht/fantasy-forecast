module Fpl
  # The single scheduled job. Every step is idempotent and self-skipping, so it
  # is safe to run hourly: syncs upsert, and forecasts only generate when there is
  # a next gameweek to forecast. A season rollover (detected by a changed team
  # list) wipes last season first so the fresh data isn't blended with the old.
  #
  # Every step reads from FPL's own API and nowhere else.
  class HourlyPipeline < ApplicationService
    def call
      reset_if_new_season

      Fpl::SyncPayloads.call    # everything FPL publishes, kept verbatim
      Fpl::SyncPlayers.call     # teams, players, availability + snapshot stats
      Fpl::SyncGameweeks.call   # gameweeks + fixtures
      Fpl::SyncPerformances.call # current gameweek's live scores
      Fpl::SyncPlayerHistories.call # last season's totals (once per player, then skipped)

      generate_forecasts
      true
    end

    private

    def reset_if_new_season
      return unless Fpl::NewSeasonDetector.call

      Rails.logger.warn "New season detected (team list changed). Wiping last season for a fresh start."
      Fpl::ResetSeason.call
    end

    # Written down rather than worked out while somebody watches a page, so the
    # week's prediction still exists on Sunday when it can be marked.
    def generate_forecasts
      gameweek = Gameweek.next_gameweek
      return Rails.logger.info("No next gameweek, skipping forecast generation.") unless gameweek

      WeeklyForecast.call(gameweek: gameweek)
      RestOfSeasonForecast.call(gameweek: gameweek)
    end
  end
end
