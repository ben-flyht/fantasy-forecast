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
  end
end
