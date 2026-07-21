module Fpl
  # The single scheduled job. Every step is idempotent and self-skipping, so it
  # is safe to run hourly: syncs upsert, odds are only fetched when the next
  # gameweek is missing them, and forecasts only generate when there is a next
  # gameweek to forecast. A season rollover (detected by a changed team list)
  # wipes last season first so the fresh data isn't blended with the old.
  class HourlyPipeline < ApplicationService
    def call
      reset_if_new_season

      Fpl::SyncPlayers.call     # teams, players, availability + snapshot stats
      Fpl::SyncGameweeks.call   # gameweeks + fixtures
      Fpl::SyncPerformances.call # current gameweek's live scores

      sync_odds
      generate_forecasts
      true
    end

    private

    def reset_if_new_season
      return unless Fpl::NewSeasonDetector.call

      Rails.logger.warn "New season detected (team list changed). Wiping last season for a fresh start."
      Fpl::ResetSeason.call
    end

    def sync_odds
      return Rails.logger.info("Odds already set for the next gameweek, skipping odds sync.") unless Odds::SyncFromCsv.needed?

      Odds::SyncFromCsv.call
    end

    def generate_forecasts
      gameweek = Gameweek.next_gameweek
      return Rails.logger.info("No next gameweek, skipping forecast generation.") unless gameweek

      ForecastRun.call(gameweek: gameweek, strategies: Strategy.active)
    end
  end
end
