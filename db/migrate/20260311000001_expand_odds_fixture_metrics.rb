class ExpandOddsFixtureMetrics < ActiveRecord::Migration[8.1]
  FIXTURE_METRICS = %w[expected_goals_for expected_goals_against team_win_odds opponent_win_odds draw_odds].freeze

  def up
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config.deep_symbolize_keys
      next unless config[:fixture]

      config[:fixture] = build_fixture_configs(config[:fixture])
      strategy.update_columns(strategy_config: config)
    end
  end

  def down
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config.deep_symbolize_keys
      next unless config[:fixture]

      team_win = config[:fixture].find { |f| f[:metric] == "team_win_odds" }
      if team_win
        team_win[:metric] = "opponent_odds"
      end

      config[:fixture].reject! { |f| %w[opponent_win_odds draw_odds].include?(f[:metric]) }
      strategy.update_columns(strategy_config: config)
    end
  end

  private

  def build_fixture_configs(existing)
    existing_by_metric = existing.index_by { |f| f[:metric].to_s }

    # Rename opponent_odds -> team_win_odds, carrying over existing weight
    if existing_by_metric["opponent_odds"] && !existing_by_metric["team_win_odds"]
      existing_by_metric["team_win_odds"] = existing_by_metric.delete("opponent_odds").merge(metric: "team_win_odds")
    end

    FIXTURE_METRICS.map do |metric|
      existing_by_metric[metric] || { metric: metric, weight: 0 }
    end
  end
end
