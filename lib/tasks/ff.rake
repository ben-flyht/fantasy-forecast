namespace :ff do
  desc "Generate forecasts and explanations for the next gameweek"
  task generate: :environment do
    gameweek = Gameweek.next_gameweek

    unless gameweek
      puts "No next gameweek available"
      exit
    end

    strategies = Strategy.active
    if strategies.empty?
      puts "No active strategies found"
      exit
    end

    puts "Generating forecasts for Gameweek #{gameweek.fpl_id}..."

    total_forecasts = 0
    strategies.each do |strategy|
      position_info = strategy.position_specific? ? "[#{strategy.position}]" : "[all positions]"
      forecasts = strategy.generate_forecasts(gameweek, generate_explanations: false)
      puts "  #{position_info}: #{forecasts.count} forecasts"
      total_forecasts += forecasts.count
    end

    puts "#{total_forecasts} forecasts from #{strategies.count} strategies"
    puts "\nGenerating explanations..."

    total_explained = 0
    strategies.each do |strategy|
      forecasts = Forecast.joins(:player)
                          .includes(player: [ :team, :statistics, :performances ])
                          .where(gameweek: gameweek, strategy: strategy)
                          .where.not(rank: nil)
                          .order(:rank)

      next if forecasts.empty?

      results = ExplanationBuilder.new(
        forecasts: forecasts.to_a,
        gameweek: gameweek,
        strategy_config: strategy.strategy_config
      ).call

      results.each do |forecast_id, explanation|
        Forecast.where(id: forecast_id).update_all(explanation: explanation)
      end

      position_label = strategy.position || "all positions"
      puts "  [#{position_label}]: #{results.count} explanations"
      total_explained += results.count
    end

    puts "#{total_explained} explanations generated"
  end

  desc "Backfill forecasts for finished gameweeks (usage: rake ff:backfill or ff:backfill[5] or ff:backfill[1,8])"
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
        forecasts = strategy.generate_forecasts(gameweek, generate_explanations: false)
        total_forecasts += forecasts.count
      end
      puts "#{gameweek.name}: done"
    end

    puts "Created #{total_forecasts} forecasts"
  end
end
