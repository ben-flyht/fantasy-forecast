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

  desc "Evaluate current strategies against historical data"
  task evaluate: :environment do
    Strategy.active.select(&:position_specific?).each do |strategy|
      puts "\n#{strategy.position.capitalize}:"
      result = StrategyEvaluator.call(strategy_config: strategy.strategy_config, position: strategy.position)
      puts "  Capture rate: #{result[:capture_rate]}%"
      puts "  Points:       #{result[:total_predicted]} / #{result[:total_optimal]} optimal"
      puts "  Gameweeks:    #{result[:gameweeks_evaluated]}"
    end
  end

  desc "Optimize strategies by testing variations (usage: rake ff:optimize or ff:optimize[forward])"
  task :optimize, [ :position ] => :environment do |_t, args|
    strategies = Strategy.active.select(&:position_specific?)
    strategies = strategies.select { |s| s.position == args[:position] } if args[:position]

    abort "No position-specific strategies found" if strategies.empty?

    strategies.each do |strategy|
      puts "\nOptimizing #{strategy.position}..."
      result = StrategyOptimizer.call(strategy: strategy)
      next if result[:skipped]

      puts "\n  Baseline: #{result[:baseline_capture_rate]}% capture rate"
      puts "  Best:     #{result[:best_capture_rate]}% capture rate"
      puts "  Change:   #{format('%+.1f', result[:improvement])}%"
      puts "  Win rate: #{result[:win_rate] ? "#{(result[:win_rate] * 100).round}%" : 'n/a'}"
      puts "  p-value:  #{result[:p_value] ? result[:p_value].round(4) : 'n/a'}"
      puts "  Evaluated: #{result[:gameweeks_evaluated]} gameweeks"

      next unless result[:improvement] > 0

      puts "\n  Improved config:"
      display_strategy_config(result[:best_config])

      print "\n  Apply this config? [y/N] "
      if $stdin.gets&.strip&.downcase == "y"
        apply_optimization!(strategy, result)
        puts "  Updated!"
      else
        puts "  Skipped."
      end
    end
  end

  desc "Optimise strategies (for scheduled use — applies improvements automatically)"
  task optimise: :environment do
    Strategy.active.select(&:position_specific?).each do |strategy|
      puts "Optimizing #{strategy.position}..."
      result = StrategyOptimizer.call(strategy: strategy)

      if result[:skipped]
        next
      elsif result[:improvement] > 0
        apply_optimization!(strategy, result)
        puts "  Applied: #{format('%+.1f', result[:improvement])}% " \
             "(#{(result[:win_rate] * 100).round}% win rate, p=#{result[:p_value].round(3)})"
      else
        puts "  No improvement found"
      end
    end
  end
end

def apply_optimization!(strategy, result)
  strategy.update!(active: false)
  Strategy.create!(
    position: strategy.position,
    active: true,
    strategy_config: result[:best_config],
    last_optimized_at: Time.current,
    optimization_log: strategy.optimization_log + [ optimization_log_entry(result) ]
  )
end

def optimization_log_entry(result)
  result.slice(
    :position, :baseline_capture_rate, :improvement,
    :win_rate, :p_value, :gameweeks_evaluated, :baseline_config, :best_config
  ).merge(timestamp: Time.current.iso8601, new_capture_rate: result[:best_capture_rate])
end

def display_strategy_config(config)
  (config[:performance] || []).each do |p|
    parts = "weight=#{p[:weight]}, lookback=#{p[:lookback]}, recency=#{p[:recency]}"
    parts += ", home_away=#{p[:home_away_weight]}" if p[:home_away_weight]
    puts "    #{p[:metric]}: #{parts}"
  end
  (config[:fixture] || []).each do |f|
    puts "    #{f[:metric]}: weight=#{f[:weight]}, lookback=#{f[:lookback] || 6}"
  end
end
