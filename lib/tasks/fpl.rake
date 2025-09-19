namespace :fpl do
  desc "Sync players from Fantasy Premier League API"
  task sync: :environment do
    puts "Starting FPL player sync..."

    if FplSyncPlayers.call
      puts "✅ Successfully synced #{Player.count} players from FPL API"
    else
      puts "❌ FPL sync failed. Check logs for details."
      exit 1
    end
  end

  desc "Show FPL sync statistics"
  task stats: :environment do
    puts "FPL Sync Statistics:"
    puts "==================="
    puts "Total players: #{Player.count}"
    puts "Goalkeepers: #{Player.where(position: 'GK').count}"
    puts "Defenders: #{Player.where(position: 'DEF').count}"
    puts "Midfielders: #{Player.where(position: 'MID').count}"
    puts "Forwards: #{Player.where(position: 'FWD').count}"
    puts ""
    puts "Teams represented: #{Player.distinct.count(:team)}"
    puts "Latest sync: #{Player.maximum(:updated_at)&.strftime('%Y-%m-%d %H:%M:%S') || 'Never'}"
  end
end
