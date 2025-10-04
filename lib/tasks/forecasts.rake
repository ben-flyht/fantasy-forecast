namespace :forecasts do
  desc "Recalculate scores for all forecasts"
  task recalculate_all: :environment do
    puts "Starting forecast score recalculation for all gameweeks..."

    # Get all gameweeks that have forecasts
    gameweeks_with_forecasts = Forecast.joins(:gameweek)
                                       .distinct
                                       .pluck("gameweeks.id", "gameweeks.fpl_id", "gameweeks.name")

    if gameweeks_with_forecasts.empty?
      puts "No gameweeks with forecasts found."
      exit
    end

    puts "Found #{gameweeks_with_forecasts.size} gameweeks with forecasts to recalculate."

    total_forecasts_updated = 0

    gameweeks_with_forecasts.each do |gameweek_id, fpl_id, name|
      print "Recalculating scores for #{name} (GW#{fpl_id})... "

      begin
        # Count forecasts before calculation
        forecast_count = Forecast.where(gameweek_id: gameweek_id).count

        # Recalculate scores for this gameweek
        Forecast.calculate_scores_for_gameweek!(gameweek_id)

        total_forecasts_updated += forecast_count
        puts "✓ (#{forecast_count} forecasts updated)"
      rescue => e
        puts "✗ Error: #{e.message}"
      end
    end

    puts "\n" + "="*50
    puts "Recalculation complete!"
    puts "Total gameweeks processed: #{gameweeks_with_forecasts.size}"
    puts "Total forecasts updated: #{total_forecasts_updated}"
  end

  desc "Recalculate scores for a specific gameweek (use GAMEWEEK=n)"
  task recalculate: :environment do
    gameweek_number = ENV["GAMEWEEK"]

    if gameweek_number.blank?
      puts "Please specify a gameweek number: rake forecasts:recalculate GAMEWEEK=5"
      exit
    end

    gameweek = Gameweek.find_by(fpl_id: gameweek_number.to_i)

    if gameweek.nil?
      puts "Gameweek #{gameweek_number} not found."
      exit
    end

    puts "Recalculating scores for #{gameweek.name}..."

    # Count forecasts before calculation
    forecast_count = Forecast.where(gameweek: gameweek).count

    if forecast_count == 0
      puts "No forecasts found for #{gameweek.name}."
      exit
    end

    begin
      # Recalculate scores
      Forecast.calculate_scores_for_gameweek!(gameweek)

      # Show some statistics
      updated_forecasts = Forecast.where(gameweek: gameweek)
                                  .where.not(total_score: nil)

      avg_score = updated_forecasts.average(:total_score)&.round(2)
      max_score = updated_forecasts.maximum(:total_score)&.round(2)
      min_score = updated_forecasts.minimum(:total_score)&.round(2)

      puts "✓ Successfully recalculated #{forecast_count} forecasts"
      puts "\nScore Statistics:"
      puts "  Average score: #{avg_score}"
      puts "  Highest score: #{max_score}"
      puts "  Lowest score: #{min_score}"
    rescue => e
      puts "✗ Error recalculating scores: #{e.message}"
      puts e.backtrace.first(5)
    end
  end

  desc "Clear all forecast scores (use with caution!)"
  task clear_scores: :environment do
    print "Are you sure you want to clear all forecast scores? (yes/no): "
    response = STDIN.gets.chomp.downcase

    unless response == "yes"
      puts "Aborted."
      exit
    end

    puts "Clearing all forecast scores..."

    Forecast.update_all(
      accuracy_score: nil,
      contrarian_bonus: nil,
      total_score: nil
    )

    puts "✓ All forecast scores have been cleared."
    puts "Run 'rake forecasts:recalculate_all' to recalculate them."
  end

  desc "Show forecast scoring statistics"
  task stats: :environment do
    puts "\n" + "="*50
    puts "FORECAST SCORING STATISTICS"
    puts "="*50

    total_forecasts = Forecast.count
    scored_forecasts = Forecast.where.not(total_score: nil).count
    unscored_forecasts = total_forecasts - scored_forecasts

    puts "\nOverall:"
    puts "  Total forecasts: #{total_forecasts}"
    puts "  Scored forecasts: #{scored_forecasts}"
    puts "  Unscored forecasts: #{unscored_forecasts}"

    if scored_forecasts > 0
      avg_score = Forecast.where.not(total_score: nil).average(:total_score)&.round(2)
      avg_accuracy = Forecast.where.not(total_score: nil).average(:accuracy_score)&.round(2)
      avg_contrarian = Forecast.where.not(total_score: nil).average(:contrarian_bonus)&.round(2)

      puts "\nScore Averages:"
      puts "  Average total score: #{avg_score}"
      puts "  Average accuracy score: #{avg_accuracy}"
      puts "  Average contrarian bonus: #{avg_contrarian}"
    end

    puts "\nBy Gameweek:"
    Forecast.joins(:gameweek)
            .group("gameweeks.id", "gameweeks.fpl_id", "gameweeks.name")
            .order("gameweeks.fpl_id")
            .pluck(
              Arel.sql("gameweeks.name"),
              Arel.sql("COUNT(forecasts.id)"),
              Arel.sql("COUNT(CASE WHEN forecasts.total_score IS NOT NULL THEN 1 END)"),
              Arel.sql("AVG(forecasts.total_score)")
            )
            .each do |name, total, scored, avg|
      puts "  #{name}: #{scored}/#{total} scored, avg: #{avg&.round(2) || 'N/A'}"
    end

    puts "\nBy Category:"
    [ "target", "avoid" ].each do |category|
      stats = Forecast.where(category: category)
      total = stats.count
      scored = stats.where.not(total_score: nil).count
      avg = stats.where.not(total_score: nil).average(:total_score)&.round(2)

      puts "  #{category.capitalize}: #{scored}/#{total} scored, avg: #{avg || 'N/A'}"
    end

    puts "\n" + "="*50
  end
end
