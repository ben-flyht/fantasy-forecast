class AddSnapshotMetricsToStrategies < ActiveRecord::Migration[8.1]
  NEW_METRICS = %w[form points_per_game now_cost selected_by_percent transfers_in transfers_out].freeze

  DEFAULT_LOOKBACK = 6
  DEFAULT_RECENCY = "linear"
  DEFAULT_HOME_AWAY_WEIGHT = 1.25

  def up
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config.deep_symbolize_keys
      next unless config[:performance]

      existing_metrics = config[:performance].map { |p| p[:metric].to_s }
      new_entries = NEW_METRICS.reject { |m| existing_metrics.include?(m) }.map do |metric|
        { metric: metric, weight: 0, lookback: DEFAULT_LOOKBACK,
          recency: DEFAULT_RECENCY, home_away_weight: DEFAULT_HOME_AWAY_WEIGHT }
      end

      next if new_entries.empty?

      config[:performance] += new_entries
      strategy.update_columns(strategy_config: config)
    end
  end

  def down
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config.deep_symbolize_keys
      next unless config[:performance]

      config[:performance].reject! { |p| NEW_METRICS.include?(p[:metric].to_s) }
      strategy.update_columns(strategy_config: config)
    end
  end
end
