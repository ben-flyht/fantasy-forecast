namespace :seed do
  desc "Generate realistic forecast seed data for 20 forecasters across weeks 1-5"
  task forecasts: :environment do
    puts "Starting forecast seed data generation..."

    # Create 20 test forecasters if they don't exist
    forecasters = []
    20.times do |i|
      email = "forecaster#{i+1}@example.com"
      user = User.find_or_create_by!(email: email) do |u|
        u.password = "password123"
        u.password_confirmation = "password123"
        u.username = "forecaster#{i+1}"
      end
      forecasters << user
    end

    puts "Created/found #{forecasters.count} forecasters"

    # Process each gameweek
    (1..5).each do |week_num|
      gameweek = Gameweek.find_by(fpl_id: week_num)
      unless gameweek
        puts "Gameweek #{week_num} not found, skipping..."
        next
      end

      puts "\nProcessing Gameweek #{week_num}..."

      # Get performance data for this gameweek
      performances = Performance.joins(:player)
                               .where(gameweek: gameweek)
                               .includes(player: :team)
                               .where.not(gameweek_score: nil)

      # Get performances from previous week for trend analysis
      prev_gameweek = Gameweek.find_by(fpl_id: week_num - 1) if week_num > 1
      prev_performances = {}
      if prev_gameweek
        Performance.where(gameweek: prev_gameweek)
                   .each { |p| prev_performances[p.player_id] = p.gameweek_score }
      end

      # Group performances by position and sort by score
      by_position = performances.group_by { |p| p.player.position }

      # Each forecaster makes their picks
      forecasters.each_with_index do |forecaster, index|
        # Determine forecaster tendencies (some are contrarian, some follow consensus)
        is_contrarian = index % 5 == 0  # 20% are contrarian
        is_form_follower = index % 3 == 0  # 33% heavily weight recent form

        targets_made = 0
        avoids_made = 0

        # Track positions filled per category to respect slot limits
        position_targets = { "goalkeeper" => 0, "defender" => 0, "midfielder" => 0, "forward" => 0 }
        position_avoids = { "goalkeeper" => 0, "defender" => 0, "midfielder" => 0, "forward" => 0 }

        [ "goalkeeper", "defender", "midfielder", "forward" ].each do |position|
          position_perfs = by_position[position] || []
          next if position_perfs.empty?

          # Sort by gameweek score
          sorted_perfs = position_perfs.sort_by(&:gameweek_score).reverse

          # Calculate momentum (comparing to previous week)
          perfs_with_momentum = sorted_perfs.map do |perf|
            prev_score = prev_performances[perf.player_id] || 0
            momentum = perf.gameweek_score - prev_score
            { performance: perf, momentum: momentum }
          end

          # Different selection strategies based on forecaster type
          if is_contrarian
            # Contrarians pick players with good momentum but lower current scores
            targets = perfs_with_momentum.select { |p| p[:momentum] > 2 }
                                        .sort_by { |p| p[:momentum] }
                                        .reverse
                                        .first(2)
            avoids = sorted_perfs.first(3)  # Avoid the top performers (expecting regression)
          elsif is_form_follower
            # Form followers pick based on recent performance trend
            targets = perfs_with_momentum.sort_by { |p| p[:momentum] }
                                        .reverse
                                        .first(3)
                                        .map { |p| p[:performance] }
            avoids = perfs_with_momentum.sort_by { |p| p[:momentum] }
                                       .first(2)
                                       .map { |p| p[:performance] }
          else
            # Regular forecasters - mix of current form and overall quality
            # Add some randomness to simulate different opinions
            top_performers = sorted_perfs.first(10)
            bottom_performers = sorted_perfs.last([ 10, sorted_perfs.length ].min)

            # Get position slot limit from config
            position_config = FantasyForecast::POSITION_CONFIG[position]
            max_slots = position_config ? position_config[:slots] : 1

            # Pick targets respecting slot limits
            num_targets = [ 1, [ max_slots, 2 ].min ].sample
            targets = top_performers.sample(num_targets)

            # Pick avoids respecting slot limits
            num_avoids = [ 1, [ max_slots, 2 ].min ].sample
            avoids = bottom_performers.sample(num_avoids)
          end

          # Get position slot limit from config
          position_config = FantasyForecast::POSITION_CONFIG[position]
          max_slots = position_config ? position_config[:slots] : 1

          # Create target forecasts
          targets.each do |target|
            perf = target.is_a?(Hash) ? target[:performance] : target
            next if targets_made >= 10  # Limit total targets per forecaster
            next if position_targets[position] >= max_slots  # Respect position slot limits

            # Skip if this forecast already exists
            existing = Forecast.find_by(
              user: forecaster,
              player: perf.player,
              gameweek: gameweek
            )

            unless existing
              Forecast.create!(
                user: forecaster,
                player: perf.player,
                gameweek: gameweek,
                category: "target"
              )
              targets_made += 1
              position_targets[position] += 1
            end
          end

          # Create avoid forecasts
          avoids.each do |avoid|
            perf = avoid.is_a?(Hash) ? avoid[:performance] : avoid
            next if avoids_made >= 5  # Limit total avoids per forecaster
            next if position_avoids[position] >= max_slots  # Respect position slot limits

            # Skip if this forecast already exists
            existing = Forecast.find_by(
              user: forecaster,
              player: perf.player,
              gameweek: gameweek
            )

            unless existing
              Forecast.create!(
                user: forecaster,
                player: perf.player,
                gameweek: gameweek,
                category: "avoid"
              )
              avoids_made += 1
              position_avoids[position] += 1
            end
          end
        end

        print "."
      end

      # Calculate scores for this gameweek
      puts "\nCalculating scores for Gameweek #{week_num}..."
      Forecast.calculate_scores_for_gameweek!(gameweek)
    end

    # Show summary statistics
    puts "\n\n" + "="*50
    puts "SEED DATA GENERATION COMPLETE"
    puts "="*50

    total_forecasts = Forecast.joins(:gameweek)
                             .where(gameweeks: { fpl_id: 1..5 })
                             .count

    puts "Total forecasts created: #{total_forecasts}"

    # Show breakdown by week
    puts "\nBy Gameweek:"
    (1..5).each do |week|
      gw = Gameweek.find_by(fpl_id: week)
      next unless gw

      week_forecasts = Forecast.where(gameweek: gw)
      targets = week_forecasts.where(category: "target").count
      avoids = week_forecasts.where(category: "avoid").count
      avg_score = week_forecasts.average(:total_score)&.round(2)

      puts "  Week #{week}: #{targets} targets, #{avoids} avoids, avg score: #{avg_score || 'N/A'}"
    end

    # Show top scorers
    puts "\nTop 5 Scoring Forecasts:"
    Forecast.joins(:user, :player, :gameweek)
           .where(gameweeks: { fpl_id: 1..5 })
           .where.not(total_score: nil)
           .order(total_score: :desc)
           .limit(5)
           .each do |forecast|
      puts "  #{forecast.user.username} - #{forecast.player.full_name} (#{forecast.category}) " \
           "GW#{forecast.gameweek.fpl_id}: #{forecast.total_score.round(2)} pts"
    end

    # Show forecaster summary
    puts "\nForecaster Performance:"
    User.joins(:forecasts)
       .joins("INNER JOIN gameweeks ON forecasts.gameweek_id = gameweeks.id")
       .where(gameweeks: { fpl_id: 1..5 })
       .group("users.id", "users.username")
       .select("users.username,
               AVG(forecasts.total_score) as avg_score,
               COUNT(forecasts.id) as total_forecasts")
       .order("avg_score DESC")
       .limit(5)
       .each do |user_stats|
      puts "  #{user_stats.username}: #{user_stats.avg_score&.round(2) || 'N/A'} avg " \
           "(#{user_stats.total_forecasts} forecasts)"
    end
  end

  desc "Clear all forecast seed data (only for test users)"
  task clear_forecasts: :environment do
    if ENV["FORCE"] != "true"
      print "This will delete all forecasts from test users (forecaster1-20@example.com). Continue? (yes/no): "
      response = STDIN.gets&.chomp&.downcase

      unless response == "yes"
        puts "Aborted."
        exit
      end
    end

    # Find test users
    test_users = User.where("email LIKE 'forecaster%@example.com'")

    if test_users.empty?
      puts "No test users found."
      exit
    end

    # Delete their forecasts
    forecast_count = Forecast.where(user: test_users).count
    Forecast.where(user: test_users).destroy_all

    puts "Deleted #{forecast_count} forecasts from #{test_users.count} test users."
  end
end
