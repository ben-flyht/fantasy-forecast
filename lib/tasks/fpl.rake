namespace :fpl do
  desc "Sync all FPL data (teams, players, gameweeks, matches, and all performances)"
  task sync: :environment do
    puts "Starting full FPL sync..."

    Rake::Task["fpl:sync_teams"].invoke
    Rake::Task["fpl:sync_players"].invoke
    Rake::Task["fpl:sync_gameweeks"].invoke
    Rake::Task["fpl:sync_matches"].invoke

    # Sync performances for all finished gameweeks
    Gameweek.finished.ordered.each do |gameweek|
      puts "\nSyncing #{gameweek.name}..."
      if Fpl::SyncPerformances.call(gameweek.fpl_id)
        puts "✅ #{gameweek.name}: #{Performance.where(gameweek: gameweek).count} performances"
      else
        puts "❌ Failed to sync #{gameweek.name}"
      end
    end

    puts "\n🎉 Complete FPL sync finished successfully!"
  end

  desc "Sync teams from Fantasy Premier League API"
  task sync_teams: :environment do
    puts "Starting FPL team sync..."

    if Fpl::SyncTeams.call
      puts "✅ Successfully synced #{Team.count} teams from FPL API"
    else
      puts "❌ Team sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Sync players from Fantasy Premier League API"
  task sync_players: :environment do
    puts "Starting FPL player sync..."

    if Fpl::SyncPlayers.call
      puts "✅ Successfully synced #{Player.count} players from FPL API"
    else
      puts "❌ FPL sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Sync gameweeks from Fantasy Premier League API"
  task sync_gameweeks: :environment do
    puts "Starting FPL gameweek sync..."

    if Fpl::SyncGameweeks.call
      current_gw = Gameweek.current_gameweek
      next_gw = Gameweek.next_gameweek

      puts "✅ Successfully synced #{Gameweek.count} gameweeks from FPL API"
      puts "Current gameweek: #{current_gw&.name || 'None'}"
      puts "Next gameweek: #{next_gw&.name || 'None'}"
    else
      puts "❌ FPL gameweek sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Sync matches from Fantasy Premier League API"
  task sync_matches: :environment do
    puts "Starting FPL match sync..."

    if Fpl::SyncMatches.call
      puts "✅ Successfully synced #{Match.count} matches from FPL API"
    else
      puts "❌ Match sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Sync player performances from Fantasy Premier League API (current or latest finished gameweek)"
  task sync_performances: :environment do
    puts "Starting FPL performance sync..."

    if Fpl::SyncPerformances.call
      synced_gw = Gameweek.current_gameweek || Gameweek.finished.ordered.last
      performance_count = synced_gw ? Performance.where(gameweek: synced_gw).count : 0
      status = synced_gw&.is_finished? ? "finished" : "in progress"

      puts "✅ Successfully synced performance data"
      puts "Gameweek: #{synced_gw&.name || 'None'} (#{status})"
      puts "Performances synced: #{performance_count}"

      # Auto-calculate forecast scores for the synced gameweek
      if synced_gw
        puts "\nCalculating forecast scores for #{synced_gw.name}..."
        Forecast.calculate_scores_for_gameweek!(synced_gw)
        scored_count = Forecast.where(gameweek: synced_gw).where.not(accuracy: nil).count
        puts "✅ Updated scores for #{scored_count} forecasts"
      end
    else
      puts "❌ FPL performance sync failed. Check logs for details."
      exit 1
    end
  end
end
