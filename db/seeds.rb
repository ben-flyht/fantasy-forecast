# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# NOTE: This seed file is safe to run - it will NOT destroy existing data.
# For bot setup, use: rake setup_fantasy_forecaster

# Sync players from FPL API (safe - uses find_or_create)
puts "Syncing players from FPL API..."
if Fpl::SyncPlayers.call
  puts "Successfully synced #{Player.count} players from FPL API"
else
  puts "FPL sync failed"
end

# Sync gameweeks from FPL API (safe - uses find_or_create)
puts "\nSyncing gameweeks from FPL API..."
if Fpl::SyncGameweeks.call
  puts "Successfully synced #{Gameweek.count} gameweeks from FPL API"
  current_gw = Gameweek.current_gameweek
  next_gw = Gameweek.next_gameweek
  puts "Current gameweek: #{current_gw&.name || 'None'}"
  puts "Next gameweek: #{next_gw&.name || 'None'}"
else
  puts "FPL gameweek sync failed"
end

puts "\nSeed complete. To set up FantasyForecaster bot, run: rake setup_fantasy_forecaster"
