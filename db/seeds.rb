# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create users
admin_user = User.find_or_create_by!(email: "admin@example.com") do |user|
  user.username = "AdminUser"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end

forecaster_user = User.find_or_create_by!(email: "forecaster@example.com") do |user|
  user.username = "ForecasterUser"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at = Time.current
end

puts "Created users:"
puts "Admin: #{admin_user.email} (#{admin_user.username})"
puts "Forecaster: #{forecaster_user.email} (#{forecaster_user.username})"

# Sync players from FPL API
puts "\nSyncing players from FPL API..."
if Fpl::SyncPlayers.call
  puts "Successfully synced #{Player.count} players from FPL API"
else
  puts "FPL sync failed, falling back to static data..."

  # Fallback to static data if API sync fails
  players_data = [
    { first_name: "Erling", last_name: "Haaland", short_name: "Haaland", team: "Manchester City", position: "forward", fpl_id: 233 },
    { first_name: "Mohamed", last_name: "Salah", short_name: "Salah", team: "Liverpool", position: "forward", fpl_id: 253 },
    { first_name: "Harry", last_name: "Kane", short_name: "Kane", team: "Tottenham Hotspur", position: "forward", fpl_id: 427 },
    { first_name: "Kevin", last_name: "De Bruyne", short_name: "De Bruyne", team: "Manchester City", position: "midfielder", fpl_id: 218 },
    { first_name: "Bruno", last_name: "Fernandes", short_name: "B.Fernandes", team: "Manchester United", position: "midfielder", fpl_id: 290 },
    { first_name: "Virgil", last_name: "van Dijk", short_name: "van Dijk", team: "Liverpool", position: "defender", fpl_id: 4 },
    { first_name: "Ruben", last_name: "Dias", short_name: "Dias", team: "Manchester City", position: "defender", fpl_id: 239 },
    { first_name: "Trent", last_name: "Alexander-Arnold", short_name: "Alexander-Arnold", team: "Liverpool", position: "defender", fpl_id: 252 },
    { first_name: "Alisson", last_name: "Becker", short_name: "Alisson", team: "Liverpool", position: "goalkeeper", fpl_id: 254 },
    { first_name: "Ederson", last_name: "Moraes", short_name: "Ederson", team: "Manchester City", position: "goalkeeper", fpl_id: 259 },
    { first_name: "Bukayo", last_name: "Saka", short_name: "Saka", team: "Arsenal", position: "midfielder", fpl_id: 356 },
    { first_name: "Gabriel", last_name: "Jesus", short_name: "Jesus", team: "Arsenal", position: "forward", fpl_id: 247 }
  ]

  players_data.each do |player_data|
    player = Player.find_or_create_by!(fpl_id: player_data[:fpl_id]) do |p|
      p.first_name = player_data[:first_name]
      p.last_name = player_data[:last_name]
      p.short_name = player_data[:short_name]
      p.team = player_data[:team]
      p.position = player_data[:position]
    end
  end

  puts "Created #{Player.count} players from fallback data"
end

# Sync gameweeks from FPL API
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

# Create sample forecasts for demonstration and testing
forecaster_user = User.find_by(email: "forecaster@example.com")
admin_user = User.find_by(email: "admin@example.com")

if forecaster_user && admin_user && Player.any?
  puts "\nCreating sample forecasts for users..."

  # Clear existing forecasts
  Forecast.destroy_all

  # Get sample players
  sample_players = Player.limit(15).order(:last_name)

  # Create additional forecaster users for consensus testing
  forecaster2 = User.find_or_create_by!(email: "forecaster2@example.com") do |user|
    user.username = "Forecaster2"
    user.password = "password123"
    user.password_confirmation = "password123"
    user.confirmed_at = Time.current
  end

  forecaster3 = User.find_or_create_by!(email: "forecaster3@example.com") do |user|
    user.username = "Forecaster3"
    user.password = "password123"
    user.password_confirmation = "password123"
    user.confirmed_at = Time.current
  end

  # Get some gameweeks for sample data
  gameweeks = Gameweek.order(:fpl_id).limit(3)

  if gameweeks.any?
    # Forecast data for multiple users to demonstrate consensus
    forecasts_data = [
      # Week 1 forecasts - show consensus
      { user: forecaster_user, player: sample_players[0], gameweek: gameweeks[0] },
      { user: forecaster2, player: sample_players[0], gameweek: gameweeks[0] },
      { user: forecaster3, player: sample_players[0], gameweek: gameweeks[0] },

      { user: forecaster_user, player: sample_players[1], gameweek: gameweeks[0] },
      { user: forecaster2, player: sample_players[1], gameweek: gameweeks[0] },

      { user: forecaster_user, player: sample_players[2], gameweek: gameweeks[0] },

      # Week 2 forecasts
      { user: forecaster_user, player: sample_players[3], gameweek: gameweeks[1] },
      { user: forecaster2, player: sample_players[4], gameweek: gameweeks[1] },
      { user: forecaster3, player: sample_players[5], gameweek: gameweeks[1] },

      # Week 3 forecasts
      { user: forecaster_user, player: sample_players[6], gameweek: gameweeks[2] },
      { user: forecaster2, player: sample_players[6], gameweek: gameweeks[2] },

      { user: forecaster_user, player: sample_players[7], gameweek: gameweeks[2] },
      { user: forecaster2, player: sample_players[7], gameweek: gameweeks[2] },
      { user: forecaster3, player: sample_players[7], gameweek: gameweeks[2] },

      { user: forecaster_user, player: sample_players[8], gameweek: gameweeks[1] },
      { user: forecaster2, player: sample_players[8], gameweek: gameweeks[1] },

      { user: forecaster_user, player: sample_players[9], gameweek: gameweeks[0] },
      { user: forecaster3, player: sample_players[10], gameweek: gameweeks[1] },
      { user: forecaster2, player: sample_players[11], gameweek: gameweeks[2] },
      { user: forecaster3, player: sample_players[12], gameweek: gameweeks[0] }
    ]

    forecasts_data.each do |forecast_data|
      Forecast.find_or_create_by!(
        user: forecast_data[:user],
        player: forecast_data[:player],
        gameweek: forecast_data[:gameweek]
      )
    end
  else
    puts "No gameweeks found, skipping forecast creation"
  end

  puts "Created #{User.count} users"
  puts "Created #{Forecast.count} forecasts across all users"

  # Show consensus examples
  puts "\nSample consensus data:"
  if gameweeks.any?
    week_1_forecasts = Forecast.joins(:gameweek).where(gameweeks: { fpl_id: gameweeks[0].fpl_id }, player: sample_players[0])
    puts "Week #{gameweeks[0].fpl_id} - #{sample_players[0].name}: #{week_1_forecasts.count} Target votes"
    week_2_forecasts = Forecast.joins(:gameweek).where(gameweeks: { fpl_id: gameweeks[2].fpl_id }, player: sample_players[7])
    puts "Week #{gameweeks[2].fpl_id} - #{sample_players[7].name}: #{week_2_forecasts.count} Target votes"
  end
else
  puts "Skipping forecasts - users or players not found"
end
