namespace :fpl do
  desc "Sync all FPL data (teams, players, gameweeks, matches, and all performances)"
  task sync: :environment do
    puts "Starting full FPL sync..."

    Rake::Task["fpl:sync_teams"].invoke
    Rake::Task["fpl:sync_players"].invoke
    Rake::Task["fpl:sync_gameweeks"].invoke
    Rake::Task["fpl:sync_matches"].invoke
    Rake::Task["fpl:sync_all_performances"].invoke

    puts "\n🎉 Complete FPL sync finished successfully!"
  end

  desc "Sync teams from Fantasy Premier League API"
  task sync_teams: :environment do
    puts "Starting FPL team sync..."

    service = Fpl::SyncTeams.new
    if service.call
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

  desc "Sync player performances for all finished gameweeks from Fantasy Premier League API"
  task sync_all_performances: :environment do
    puts "Starting FPL performance sync for all finished gameweeks..."

    finished_gameweeks = Gameweek.finished.ordered

    if finished_gameweeks.empty?
      puts "❌ No finished gameweeks found"
      exit 1
    end

    puts "Found #{finished_gameweeks.count} finished gameweeks to sync"

    total_synced = 0
    failed_gameweeks = []

    finished_gameweeks.each do |gameweek|
      puts "\nSyncing #{gameweek.name}..."

      if Fpl::SyncPerformances.call(gameweek.fpl_id)
        synced_count = Performance.where(gameweek: gameweek).count
        total_synced += synced_count
        puts "✅ #{gameweek.name}: #{synced_count} performances synced"
      else
        failed_gameweeks << gameweek.name
        puts "❌ Failed to sync #{gameweek.name}"
      end
    end

    if failed_gameweeks.empty?
      puts "\n🎉 Successfully synced all finished gameweeks!"
      puts "Total performances in database: #{Performance.count}"

      # Show breakdown by gameweek
      puts "\nPerformance breakdown:"
      Performance.joins(:gameweek).group("gameweeks.name").count.each do |gw_name, count|
        puts "  #{gw_name}: #{count} performances"
      end
    else
      puts "\n❌ Sync completed with errors. Failed gameweeks: #{failed_gameweeks.join(', ')}"
      exit 1
    end
  end

  desc "Show FPL sync statistics"
  task stats: :environment do
    puts "FPL Sync Statistics:"
    puts "==================="
    puts "Total players: #{Player.count}"
    puts "Goalkeepers: #{Player.where(position: 'goalkeeper').count}"
    puts "Defenders: #{Player.where(position: 'defender').count}"
    puts "Midfielders: #{Player.where(position: 'midfielder').count}"
    puts "Forwards: #{Player.where(position: 'forward').count}"
    puts ""
    puts "Teams represented: #{Player.distinct.count(:team_id)}"
    puts "Latest player sync: #{Player.maximum(:updated_at)&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
    puts ""
    puts "Total gameweeks: #{Gameweek.count}"
    puts "Current gameweek: #{Gameweek.current_gameweek&.name || 'None'}"
    puts "Next gameweek: #{Gameweek.next_gameweek&.name || 'None'}"
    puts "Finished gameweeks: #{Gameweek.finished.count}"
    puts "Latest gameweek sync: #{Gameweek.maximum(:updated_at)&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
    puts ""
    puts "Total performances: #{Performance.count}"
    puts "Latest performance sync: #{Performance.maximum(:updated_at)&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
  end
end
