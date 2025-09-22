namespace :fpl do
  desc "Sync players and gameweeks"
  task sync: :environment do
    puts "Starting FPL sync (players and gameweeks)..."

    Rake::Task["fpl:sync_players"].invoke
    Rake::Task["fpl:sync_gameweeks"].invoke

    puts "\n🎉 FPL sync completed successfully!"
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

  desc "Sync both players and gameweeks from FPL API"
  task sync_all: :environment do
    puts "Starting full FPL sync (players and gameweeks)..."

    # Sync players first
    puts "\n1. Syncing players..."
    if Fpl::SyncPlayers.call
      puts "✅ Successfully synced #{Player.count} players"
    else
      puts "❌ Player sync failed"
      exit 1
    end

    # Then sync gameweeks
    puts "\n2. Syncing gameweeks..."
    if Fpl::SyncGameweeks.call
      current_gw = Gameweek.current_gameweek
      next_gw = Gameweek.next_gameweek

      puts "✅ Successfully synced #{Gameweek.count} gameweeks"
      puts "Current gameweek: #{current_gw&.name || 'None'}"
      puts "Next gameweek: #{next_gw&.name || 'None'}"
    else
      puts "❌ Gameweek sync failed"
      exit 1
    end

    puts "\n🎉 Full FPL sync completed successfully!"
  end

  desc "Sync player performances from Fantasy Premier League API (latest finished gameweek)"
  task sync_performances: :environment do
    puts "Starting FPL performance sync..."

    if Fpl::SyncPerformances.call
      latest_finished_gw = Gameweek.finished.ordered.last
      performance_count = latest_finished_gw ? Performance.where(gameweek: latest_finished_gw).count : 0

      puts "✅ Successfully synced performance data"
      puts "Latest finished gameweek: #{latest_finished_gw&.name || 'None'}"
      puts "Performances synced: #{performance_count}"
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
      Performance.joins(:gameweek).group('gameweeks.name').count.each do |gw_name, count|
        puts "  #{gw_name}: #{count} performances"
      end
    else
      puts "\n❌ Sync completed with errors. Failed gameweeks: #{failed_gameweeks.join(', ')}"
      exit 1
    end
  end

  desc "Sync player performances for a specific gameweek"
  task :sync_performances_for_gameweek, [:gameweek_id] => :environment do |t, args|
    gameweek_id = args[:gameweek_id]

    unless gameweek_id
      puts "❌ Please provide a gameweek ID: rake fpl:sync_performances_for_gameweek[1]"
      exit 1
    end

    puts "Starting FPL performance sync for gameweek #{gameweek_id}..."

    if Fpl::SyncPerformances.call(gameweek_id.to_i)
      gameweek = Gameweek.find_by(fpl_id: gameweek_id.to_i)
      performance_count = gameweek ? Performance.where(gameweek: gameweek).count : 0

      puts "✅ Successfully synced performance data for gameweek #{gameweek_id}"
      puts "Performances synced: #{performance_count}"
    else
      puts "❌ FPL performance sync failed for gameweek #{gameweek_id}. Check logs for details."
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
    puts "Teams represented: #{Player.distinct.count(:team)}"
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
