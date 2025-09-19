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
