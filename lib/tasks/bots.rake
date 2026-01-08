desc "Generate forecasts for all active strategies for the next gameweek"
task bots: :environment do
  gameweek = Gameweek.next_gameweek

  unless gameweek
    puts "No next gameweek available"
    exit
  end

  puts "Generating forecasts for Gameweek #{gameweek.fpl_id}..."

  strategies = Strategy.active
  total_forecasts = 0

  strategies.each do |strategy|
    position_info = strategy.position_specific? ? "[#{strategy.position}]" : "[all positions]"
    forecasts = strategy.generate_forecasts(gameweek)
    puts "  Strategy #{strategy.id} #{position_info}: #{forecasts.count} forecasts"
    total_forecasts += forecasts.count
  end

  puts "\n" + "=" * 60
  puts "Forecast generation complete!"
  puts "Total: #{total_forecasts} forecasts from #{strategies.count} strategies"
  puts "=" * 60
end

namespace :bots do
  desc "Backfill bot forecasts for finished gameweeks (usage: rake bots:backfill or rake bots:backfill[5] or rake bots:backfill[1,8])"
  task :backfill, [ :start_gameweek, :end_gameweek ] => :environment do |_t, args|
    if args[:start_gameweek] && args[:end_gameweek]
      gameweeks = Gameweek.where(fpl_id: args[:start_gameweek].to_i..args[:end_gameweek].to_i).order(:fpl_id)
    elsif args[:start_gameweek]
      gameweeks = Gameweek.where(fpl_id: args[:start_gameweek].to_i)
    else
      gameweeks = Gameweek.finished.order(:fpl_id)
    end

    abort "No gameweeks found" if gameweeks.empty?

    strategies = Strategy.active
    abort "No active strategies found" if strategies.empty?

    total_forecasts = 0

    gameweeks.each do |gameweek|
      next if Performance.where(gameweek: gameweek).none?

      strategies.each do |strategy|
        forecasts = strategy.generate_forecasts(gameweek)
        total_forecasts += forecasts.count
      end
      puts "#{gameweek.name}: ✓"
    end

    puts "Created #{total_forecasts} forecasts"
  end
end
