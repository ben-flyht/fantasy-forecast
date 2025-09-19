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
  user.role = "admin"
end

prophet_user = User.find_or_create_by!(email: "prophet@example.com") do |user|
  user.username = "ProphetUser"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = "prophet"
end

puts "Created users:"
puts "Admin: #{admin_user.email} (#{admin_user.username}) - Role: #{admin_user.role}"
puts "Prophet: #{prophet_user.email} (#{prophet_user.username}) - Role: #{prophet_user.role}"

# Sync players from FPL API
puts "\nSyncing players from FPL API..."
if FplSyncPlayers.call
  puts "Successfully synced #{Player.count} players from FPL API"
else
  puts "FPL sync failed, falling back to static data..."

  # Fallback to static data if API sync fails
  players_data = [
    { name: "Erling Haaland", team: "Manchester City", position: "FWD", bye_week: 7, fpl_id: 233 },
    { name: "Mohamed Salah", team: "Liverpool", position: "FWD", bye_week: 5, fpl_id: 253 },
    { name: "Harry Kane", team: "Tottenham Hotspur", position: "FWD", bye_week: 8, fpl_id: 427 },
    { name: "Kevin De Bruyne", team: "Manchester City", position: "MID", bye_week: 7, fpl_id: 218 },
    { name: "Bruno Fernandes", team: "Manchester United", position: "MID", bye_week: 4, fpl_id: 290 },
    { name: "Virgil van Dijk", team: "Liverpool", position: "DEF", bye_week: 5, fpl_id: 4 },
    { name: "Ruben Dias", team: "Manchester City", position: "DEF", bye_week: 7, fpl_id: 239 },
    { name: "Trent Alexander-Arnold", team: "Liverpool", position: "DEF", bye_week: 5, fpl_id: 252 },
    { name: "Alisson", team: "Liverpool", position: "GK", bye_week: 5, fpl_id: 254 },
    { name: "Ederson", team: "Manchester City", position: "GK", bye_week: 7, fpl_id: 259 },
    { name: "Bukayo Saka", team: "Arsenal", position: "MID", bye_week: 6, fpl_id: 356 },
    { name: "Gabriel Jesus", team: "Arsenal", position: "FWD", bye_week: 6, fpl_id: 247 }
  ]

  players_data.each do |player_data|
    player = Player.find_or_create_by!(fpl_id: player_data[:fpl_id]) do |p|
      p.name = player_data[:name]
      p.team = player_data[:team]
      p.position = player_data[:position]
      p.bye_week = player_data[:bye_week]
    end
  end

  puts "Created #{Player.count} players from fallback data"
end

# Create sample predictions for the Prophet user
prophet_user = User.find_by(email: "prophet@example.com")
if prophet_user && Player.any?
  puts "\nCreating sample predictions for Prophet user..."

  # Get some sample players
  sample_players = Player.limit(10).order(:name)

  predictions_data = [
    # Weekly predictions
    {
      player: sample_players[0],
      week: 1,
      season_type: "weekly",
      category: "must_have"
    },
    {
      player: sample_players[1],
      week: 1,
      season_type: "weekly",
      category: "better_than_expected"
    },
    {
      player: sample_players[2],
      week: 2,
      season_type: "weekly",
      category: "worse_than_expected"
    },
    {
      player: sample_players[3],
      week: 3,
      season_type: "weekly",
      category: "must_have"
    },
    # Rest of season predictions
    {
      player: sample_players[4],
      season_type: "rest_of_season",
      category: "must_have"
    },
    {
      player: sample_players[5],
      season_type: "rest_of_season",
      category: "better_than_expected"
    },
    {
      player: sample_players[6],
      season_type: "rest_of_season",
      category: "worse_than_expected"
    }
  ]

  predictions_data.each do |prediction_data|
    prediction = Prediction.find_or_create_by!(
      user: prophet_user,
      player: prediction_data[:player],
      week: prediction_data[:week],
      season_type: prediction_data[:season_type]
    ) do |p|
      p.category = prediction_data[:category]
    end
  end

  puts "Created #{Prediction.count} predictions for Prophet user"
else
  puts "Skipping predictions - no Prophet user or players found"
end
