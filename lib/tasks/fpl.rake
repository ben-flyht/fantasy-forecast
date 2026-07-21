namespace :fpl do
  # The scheduled sync now lives in `ff:hourly` (Fpl::HourlyPipeline), which is
  # idempotent and safe to run every hour. The tasks below are manual utilities.

  desc "Sync player performances for the current/latest finished gameweek (manual re-sync)"
  task sync_performances: :environment do
    puts "Starting FPL performance sync..."

    if Fpl::SyncPerformances.call
      synced_gw = Gameweek.current_gameweek || Gameweek.finished.ordered.last
      performance_count = synced_gw ? Performance.where(gameweek: synced_gw).count : 0
      status = synced_gw&.is_finished? ? "finished" : "in progress"

      puts "✅ Synced performance data"
      puts "Gameweek: #{synced_gw&.name || 'None'} (#{status})"
      puts "Performances synced: #{performance_count}"
    else
      puts "❌ FPL performance sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Force a fresh season now: delete all FPL data, then re-run the full pipeline (tuned strategies are kept)"
  task new_season: :environment do
    puts "⚠️  This DELETES all FPL data for a fresh season. Strategies are kept."
    puts "Current: #{Team.count} teams, #{Player.count} players, #{Gameweek.count} gameweeks, " \
         "#{Performance.count} performances, #{Statistic.count} statistics, #{Forecast.count} forecasts."

    unless ENV["CONFIRM"] == "yes"
      abort "\nAborted. Re-run to confirm: rake fpl:new_season CONFIRM=yes"
    end

    puts "\nWiping FPL data..."
    deleted = Fpl::ResetSeason.call
    puts "Deleted: #{deleted.map { |table, count| "#{count} #{table}" }.join(', ')}"

    puts "\nRe-seeding via the pipeline..."
    Fpl::HourlyPipeline.call

    if Team.count.zero? || Player.count.zero?
      puts "\n⚠️  WARNING: sync produced #{Team.count} teams / #{Player.count} players. " \
           "Check the FPL API, then re-run 'rake ff:hourly'."
    else
      puts "\n🎉 Fresh season ready: #{Team.count} teams, #{Player.count} players, #{Gameweek.count} gameweeks."
    end
  end
end
