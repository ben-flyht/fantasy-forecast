desc "Generate forecasts for all active strategies for the next gameweek"
task bots: :environment do
  gameweek = Gameweek.next_gameweek

  unless gameweek
    puts "No next gameweek available"
    exit
  end

  puts "Generating strategy forecasts for Gameweek #{gameweek.fpl_id}..."

  strategies = Strategy.active.includes(:user)
  total_forecasts = 0

  strategies.each do |strategy|
    puts "\n#{strategy.username}: #{strategy.description}"

    forecasts = strategy.generate_forecasts(gameweek)

    puts "  ✓ Created #{forecasts.count} forecasts"
    total_forecasts += forecasts.count
  end

  puts "\n" + "=" * 60
  puts "Strategy forecast generation complete!"
  puts "Total: #{total_forecasts} forecasts for #{strategies.count} strategies"
  puts "=" * 60
end

namespace :bots do
  desc "Backfill strategy forecasts for finished gameweeks (usage: rake bots:backfill or rake bots:backfill[5] or rake bots:backfill[1,8])"
  task :backfill, [ :start_gameweek, :end_gameweek ] => :environment do |t, args|
    # Determine which gameweeks to backfill
    if args[:start_gameweek] && args[:end_gameweek]
      start_gw = args[:start_gameweek].to_i
      end_gw = args[:end_gameweek].to_i
      gameweeks = Gameweek.where(fpl_id: start_gw..end_gw).order(:fpl_id)
    elsif args[:start_gameweek]
      gw_id = args[:start_gameweek].to_i
      gameweeks = Gameweek.where(fpl_id: gw_id)
    else
      # Default: all finished gameweeks
      gameweeks = Gameweek.finished.order(:fpl_id)
    end

    if gameweeks.empty?
      puts "No gameweeks found to backfill"
      exit
    end

    # Get all active strategies
    strategies = Strategy.active.includes(:user)

    if strategies.empty?
      puts "No active strategies found. Run 'rake bots:seed' first."
      exit
    end

    puts "=" * 70
    puts "Backfilling Strategy Forecasts"
    puts "=" * 70
    puts "Strategies: #{strategies.map(&:username).join(', ')}"
    puts "Gameweeks: #{gameweeks.map { |gw| "GW#{gw.fpl_id}" }.join(', ')}"
    puts "=" * 70
    puts

    total_forecasts = 0
    total_cleared = 0

    gameweeks.each do |gameweek|
      puts "Gameweek #{gameweek.fpl_id}: #{gameweek.name}"
      puts "-" * 70

      # Check if this gameweek has performance data
      performance_count = Performance.where(gameweek: gameweek).count
      if performance_count == 0
        puts "  ⚠ Skipping - no performance data available"
        puts
        next
      end

      strategies.each do |strategy|
        # Clear existing forecasts for this strategy and gameweek
        cleared = Forecast.where(user: strategy.user, gameweek: gameweek).count
        Forecast.where(user: strategy.user, gameweek: gameweek).destroy_all
        total_cleared += cleared

        # Generate forecasts using only data that would have been available at the time
        begin
          forecasts = strategy.generate_forecasts(gameweek)
          puts "  #{strategy.username}: ✓ #{forecasts.count} forecasts (cleared #{cleared})"
          total_forecasts += forecasts.count
        rescue => e
          puts "  #{strategy.username}: ✗ Error - #{e.message}"
        end
      end

      puts
    end

    puts "=" * 70
    puts "Backfill Complete!"
    puts "Cleared: #{total_cleared} forecasts"
    puts "Created: #{total_forecasts} forecasts"
    puts "Gameweeks processed: #{gameweeks.count}"
    puts "Strategies: #{strategies.count}"
    puts "=" * 70
  end

  desc "Seed strategies from config/bots.yml"
  task seed: :environment do
    strategy_configs = YAML.load_file(Rails.root.join("config", "bots.yml"))

    puts "Seeding strategies from config/bots.yml..."

    strategy_configs["bots"].each do |config|
      username = config["username"]
      description = config["description"]
      strategy_config = config["config"]

      begin
        strategy = Strategy.create_with_user!(
          username: username,
          description: description,
          strategy_config: strategy_config,
          active: true
        )
        puts "  ✓ #{username}"
      rescue ActiveRecord::RecordInvalid => e
        puts "  ✗ #{username}: #{e.message}"
      end
    end

    puts "\nStrategy seeding complete! Total: #{Strategy.count} strategies"
  end

  desc "Clear all strategy forecasts for next gameweek"
  task clear_forecasts: :environment do
    gameweek = Gameweek.next_gameweek

    unless gameweek
      puts "No next gameweek available"
      exit
    end

    strategy_users = User.bots
    count = Forecast.where(user: strategy_users, gameweek: gameweek).count

    Forecast.where(user: strategy_users, gameweek: gameweek).destroy_all

    puts "Cleared #{count} strategy forecasts for Gameweek #{gameweek.fpl_id}"
  end
end
