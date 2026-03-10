class AddOddsAndHomeAwayToStrategies < ActiveRecord::Migration[8.1]
  # Metrics excluded from all positions (non-scoring / structural)
  EXCLUDED_METRICS = %w[minutes starts chance_of_playing].freeze

  # Metrics restricted to goalkeeper only
  GK_ONLY_METRICS = %w[saves penalties_saved].freeze

  # Clean sheets excluded from forwards only (MID earns CS points)
  FWD_EXCLUDED_METRICS = %w[clean_sheets].freeze

  FIXTURE_METRICS = %w[expected_goals_for expected_goals_against opponent_odds].freeze

  ALL_PERFORMANCE_METRICS = %w[
    total_points goals_scored assists clean_sheets goals_conceded
    own_goals penalties_saved penalties_missed yellow_cards red_cards
    saves bonus bps influence creativity threat ict_index
    expected_goals expected_assists expected_goal_involvements
    expected_goals_conceded clearances_blocks_interceptions
    recoveries tackles defensive_contribution
  ].freeze

  DEFAULT_LOOKBACK = 6
  DEFAULT_RECENCY = "linear"
  DEFAULT_HOME_AWAY_WEIGHT = 1.25

  def up
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config.deep_symbolize_keys
      position = strategy.position
      next unless position

      full_config = build_full_palette(config, position)

      Strategy.where(id: strategy.id).update_all(active: false)
      new_strategy = Strategy.create!(
        position: position,
        active: true,
        strategy_config: full_config,
        optimization_log: strategy.optimization_log
      )

      puts "  #{position}: #{full_config[:performance].size} performance + #{full_config[:fixture].size} fixture metrics"
    end
  end

  def down
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config.deep_symbolize_keys

      config[:performance]&.reject! { |p| p[:weight]&.zero? }
      config[:fixture]&.reject! { |f| f[:weight]&.zero? }

      strategy.update!(strategy_config: config)
    end
  end

  private

  def build_full_palette(config, position)
    existing_performance = config[:performance] || []
    existing_fixture = config[:fixture] || []

    palette_metrics = performance_metrics_for(position)
    new_performance = build_performance_configs(existing_performance, palette_metrics)
    new_fixture = build_fixture_configs(existing_fixture)

    config.merge(performance: new_performance, fixture: new_fixture)
  end

  def performance_metrics_for(position)
    metrics = ALL_PERFORMANCE_METRICS - EXCLUDED_METRICS
    metrics -= GK_ONLY_METRICS unless position == "goalkeeper"
    metrics -= FWD_EXCLUDED_METRICS if position == "forward"
    metrics
  end

  def build_performance_configs(existing, palette_metrics)
    existing_by_metric = existing.index_by { |p| p[:metric].to_s }

    palette_metrics.map do |metric|
      if existing_by_metric[metric]
        perf = existing_by_metric[metric].dup
        perf[:home_away_weight] ||= DEFAULT_HOME_AWAY_WEIGHT
        perf
      else
        {
          metric: metric,
          weight: 0,
          lookback: DEFAULT_LOOKBACK,
          recency: DEFAULT_RECENCY,
          home_away_weight: DEFAULT_HOME_AWAY_WEIGHT
        }
      end
    end
  end

  def build_fixture_configs(existing)
    existing_by_metric = existing.index_by { |f| f[:metric].to_s }

    FIXTURE_METRICS.map do |metric|
      existing_by_metric[metric] || { metric: metric, weight: 0 }
    end
  end
end
