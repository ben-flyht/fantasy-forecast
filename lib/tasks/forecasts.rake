namespace :forecasts do
  desc "Recalculate scores for all forecasts"
  task recalculate_all: :environment do
    puts "Recalculating scores for all gameweeks..."

    begin
      gameweeks = Gameweek.joins(:performances).distinct

      gameweeks.each do |gameweek|
        print "  Calculating scores for #{gameweek.name}..."
        Forecast.calculate_scores_for_gameweek!(gameweek)
        count = Forecast.where(gameweek: gameweek).where.not(accuracy: nil).count
        puts " ✓ #{count} forecasts"
      end

      total_scores = Forecast.where.not(accuracy: nil).count
      puts "\n✓ Successfully calculated scores for #{total_scores} forecasts"
    rescue => e
      puts "✗ Error calculating scores: #{e.message}"
      puts e.backtrace.first(5)
    end
  end

  desc "Recalculate scores for all forecasts (alias for recalculate_all)"
  task recalculate: :environment do
    Rake::Task["forecasts:recalculate_all"].invoke
  end

  desc "Show forecast scoring statistics"
  task stats: :environment do
    puts "\n" + "="*50
    puts "FORECAST SCORING STATISTICS"
    puts "="*50

    total_forecasts = Forecast.count
    scored_forecasts = Forecast.where.not(accuracy: nil).count
    unscored_forecasts = total_forecasts - scored_forecasts

    puts "\nOverall:"
    puts "  Total forecasts: #{total_forecasts}"
    puts "  Scored forecasts: #{scored_forecasts}"
    puts "  Unscored forecasts: #{unscored_forecasts}"

    if scored_forecasts > 0
      avg_accuracy = Forecast.where.not(accuracy: nil).average(:accuracy)&.round(2)

      puts "\nScore Averages:"
      puts "  Average accuracy: #{avg_accuracy}"
    end

    puts "\nBy Gameweek:"
    Forecast.joins(:gameweek)
         .where.not(accuracy: nil)
         .group("gameweeks.id", "gameweeks.fpl_id", "gameweeks.name")
         .order("gameweeks.fpl_id")
         .pluck(
           Arel.sql("gameweeks.name"),
           Arel.sql("COUNT(forecasts.id)"),
           Arel.sql("AVG(forecasts.accuracy)")
         )
         .each do |name, total, avg|
      puts "  #{name}: #{total} scored, avg: #{avg&.round(2) || 'N/A'}"
    end

    puts "\n" + "="*50
  end
end
