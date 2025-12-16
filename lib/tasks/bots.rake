desc "Generate forecasts for all active strategies for the next gameweek"
task bots: :environment do
  gameweek = Gameweek.next_gameweek

  unless gameweek
    puts "No next gameweek available"
    exit
  end

  puts "Generating strategy forecasts for Gameweek #{gameweek.fpl_id}..."

  # Group strategies by user to handle users with multiple position-specific strategies
  strategies_by_user = Strategy.active.includes(:user).group_by(&:user)
  total_forecasts = 0
  total_users = 0

  strategies_by_user.each do |user, strategies|
    total_users += 1
    user_forecasts = 0

    # Clear existing forecasts for this user/gameweek before generating new ones
    Forecast.where(user: user, gameweek: gameweek).destroy_all

    puts "\n#{user.username}:"

    strategies.each do |strategy|
      position_info = strategy.position_specific? ? " [#{strategy.position}]" : " [general]"
      puts "  Strategy#{position_info}"

      forecasts = strategy.generate_forecasts(gameweek)
      user_forecasts += forecasts.count
    end

    puts "  ✓ Created #{user_forecasts} forecasts"
    total_forecasts += user_forecasts
  end

  puts "\n" + "=" * 60
  puts "Strategy forecast generation complete!"
  puts "Total: #{total_forecasts} forecasts for #{total_users} bot users"
  puts "=" * 60
end

namespace :bots do
  desc "Backfill bot forecasts for finished gameweeks (usage: rake bots:backfill or rake bots:backfill[5] or rake bots:backfill[1,8])"
  task :backfill, [ :start_gameweek, :end_gameweek ] => :environment do |t, args|
    if args[:start_gameweek] && args[:end_gameweek]
      gameweeks = Gameweek.where(fpl_id: args[:start_gameweek].to_i..args[:end_gameweek].to_i).order(:fpl_id)
    elsif args[:start_gameweek]
      gameweeks = Gameweek.where(fpl_id: args[:start_gameweek].to_i)
    else
      gameweeks = Gameweek.finished.order(:fpl_id)
    end

    abort "No gameweeks found" if gameweeks.empty?

    strategies_by_user = Strategy.active.includes(:user).group_by(&:user)
    abort "No active strategies found" if strategies_by_user.empty?

    total_forecasts = 0

    gameweeks.each do |gameweek|
      next if Performance.where(gameweek: gameweek).none?

      strategies_by_user.each do |user, user_strategies|
        Forecast.where(user: user, gameweek: gameweek).destroy_all

        user_strategies.each do |strategy|
          forecasts = strategy.generate_forecasts(gameweek)
          total_forecasts += forecasts.count
        end
      end
      puts "#{gameweek.name}: ✓"
    end

    puts "Created #{total_forecasts} forecasts"
  end
end
