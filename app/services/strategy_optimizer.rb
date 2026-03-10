class StrategyOptimizer < ApplicationService
  include StatisticalTesting

  RECENCY_OPTIONS = %w[none linear exponential].freeze
  LOOKBACK_OPTIONS = [ 4, 6, 8, 10, 12 ].freeze
  WEIGHT_STEPS = [ -0.2, -0.1, 0.1, 0.2 ].freeze
  HOME_AWAY_WEIGHT_OPTIONS = [ nil, 1.25, 1.5, 2.0 ].freeze

  MIN_WIN_RATE = 0.65
  MIN_IMPROVEMENT = 2.0
  SIGNIFICANCE_LEVEL = 0.05
  COOLDOWN_WEEKS = 4

  def initialize(strategy:, candidates_per_generation: 8, generations: 2)
    @strategy = strategy
    @position = strategy.position
    @candidates_per_generation = candidates_per_generation
    @generations = generations
  end

  def call
    raise ArgumentError, "Strategy must be position-specific" unless @position

    return handle_cooldown if in_cooldown?

    run_optimization
  end

  private

  def handle_cooldown
    puts "  Skipping — last optimized #{time_since_last_optimization} ago (cooldown: #{COOLDOWN_WEEKS} weeks)"
    skip_result
  end

  def run_optimization
    baseline = evaluate(@strategy.strategy_config)
    best = { config: @strategy.strategy_config, result: baseline }

    @generations.times do |gen|
      candidates = generate_candidates(best[:config]).shuffle.first(@candidates_per_generation)
      winner = find_best_candidate(candidates, baseline)
      best = log_generation(gen, winner, best)
    end

    build_result(baseline, best)
  end

  def log_generation(gen, winner, best)
    if winner
      puts "  Gen #{gen + 1}: #{winner[:result][:capture_rate]}% " \
           "(wins #{format_percent(winner[:win_rate])}, p=#{winner[:p_value].round(3)})"
      winner
    else
      puts "  Gen #{gen + 1}: no confident improvement"
      best
    end
  end

  def evaluate(config)
    StrategyEvaluator.call(strategy_config: config, position: @position)
  end

  def find_best_candidate(candidates, baseline)
    candidates.filter_map { |config| evaluate_candidate(config, baseline) }
              .max_by { |w| w[:result][:capture_rate] }
  end

  def evaluate_candidate(config, baseline)
    result = evaluate(config)
    return unless result[:capture_rate] - baseline[:capture_rate] >= MIN_IMPROVEMENT

    win_rate = gameweek_win_rate(result, baseline)
    return unless win_rate >= MIN_WIN_RATE

    p_value = paired_t_test(result[:per_gameweek], baseline[:per_gameweek])
    return unless p_value < SIGNIFICANCE_LEVEL

    { config: config, result: result, win_rate: win_rate, p_value: p_value }
  end

  def gameweek_win_rate(candidate, baseline)
    pairs = candidate[:per_gameweek].zip(baseline[:per_gameweek])
    wins = pairs.count { |c, b| c[:capture] > b[:capture] }
    wins.to_f / pairs.size
  end

  def in_cooldown?
    return false unless @strategy.last_optimized_at

    @strategy.last_optimized_at > COOLDOWN_WEEKS.weeks.ago
  end

  def time_since_last_optimization
    distance_in_days = ((Time.current - @strategy.last_optimized_at) / 1.day).round
    "#{distance_in_days} days"
  end

  def generate_candidates(base_config)
    candidates = []
    candidates.concat(vary_weights(base_config))
    candidates.concat(vary_lookbacks(base_config))
    candidates.concat(vary_recency(base_config))
    candidates.concat(vary_fixture(base_config))
    candidates.concat(vary_home_away(base_config))
    candidates
  end

  def vary_weights(base_config)
    vary_performance(base_config) do |perf, delta|
      new_weight = (perf[:weight] + delta).round(2)
      next if new_weight <= 0 || new_weight > 1.0

      perf[:weight] = new_weight
    end
  end

  def vary_lookbacks(base_config)
    active_performance_indices(base_config).flat_map do |idx|
      LOOKBACK_OPTIONS.filter_map do |lookback|
        next if lookback == base_config[:performance][idx][:lookback]

        new_config = deep_copy(base_config)
        new_config[:performance][idx][:lookback] = lookback
        new_config
      end
    end
  end

  def vary_recency(base_config)
    active_performance_indices(base_config).flat_map do |idx|
      RECENCY_OPTIONS.filter_map do |recency|
        next if recency == base_config[:performance][idx][:recency]

        new_config = deep_copy(base_config)
        new_config[:performance][idx][:recency] = recency
        new_config
      end
    end
  end

  def vary_fixture(base_config)
    return [] unless base_config[:fixture]

    base_config[:fixture].each_index.flat_map do |idx|
      WEIGHT_STEPS.filter_map { |delta| build_fixture_variant(base_config, idx, delta) }
    end
  end

  def build_fixture_variant(base_config, idx, delta)
    new_weight = (base_config[:fixture][idx][:weight] + delta).round(2)
    return if new_weight.abs > 1.0

    new_config = deep_copy(base_config)
    new_config[:fixture][idx][:weight] = new_weight
    new_config
  end

  def vary_home_away(base_config)
    active_performance_indices(base_config).flat_map do |idx|
      HOME_AWAY_WEIGHT_OPTIONS.filter_map do |ha_weight|
        next if ha_weight == base_config[:performance][idx][:home_away_weight]

        new_config = deep_copy(base_config)
        new_config[:performance][idx][:home_away_weight] = ha_weight
        new_config
      end
    end
  end

  def active_performance_indices(base_config)
    return [] unless base_config[:performance]

    base_config[:performance].each_index.reject { |idx| base_config[:performance][idx][:weight]&.zero? }
  end

  def vary_performance(base_config)
    return [] unless base_config[:performance]

    base_config[:performance].each_index.flat_map do |idx|
      WEIGHT_STEPS.filter_map do |delta|
        new_config = deep_copy(base_config)
        perf = new_config[:performance][idx]
        next unless yield(perf, delta)

        normalize_weights!(new_config[:performance])
        new_config
      end
    end
  end

  def normalize_weights!(performance_configs)
    total = performance_configs.sum { |p| p[:weight] }
    return if total.zero?

    performance_configs.each { |p| p[:weight] = (p[:weight] / total).round(2) }
  end

  def deep_copy(config)
    Marshal.load(Marshal.dump(config))
  end

  def build_result(baseline, best)
    {
      position: @position,
      baseline_capture_rate: baseline[:capture_rate],
      best_capture_rate: best[:result][:capture_rate],
      improvement: (best[:result][:capture_rate] - baseline[:capture_rate]).round(1),
      win_rate: best[:win_rate], p_value: best[:p_value],
      baseline_config: @strategy.strategy_config,
      best_config: best[:config],
      gameweeks_evaluated: best[:result][:gameweeks_evaluated]
    }
  end

  def skip_result
    {
      position: @position,
      baseline_capture_rate: nil, best_capture_rate: nil,
      improvement: 0.0, win_rate: nil, p_value: nil, skipped: true,
      baseline_config: @strategy.strategy_config,
      best_config: @strategy.strategy_config,
      gameweeks_evaluated: 0
    }
  end

  def format_percent(value)
    value ? "#{(value * 100).round}%" : "n/a"
  end
end
