class OptimizeForwardAndDefenderStrategies < ActiveRecord::Migration[8.1]
  def up
    # Forward: switch from exponential xG to linear pts/xGI/ICT with longer lookback
    # Backtesting GW10-28: 48.6% capture vs 43.8% current (+4.8%)
    Strategy.where(position: "forward", active: true).update_all(active: false)
    Strategy.create!(
      position: "forward",
      active: true,
      strategy_config: {
        "performance" => [
          { "metric" => "total_points", "weight" => 0.5, "lookback" => 10, "recency" => "linear" },
          { "metric" => "expected_goal_involvements", "weight" => 0.4, "lookback" => 10, "recency" => "linear" },
          { "metric" => "ict_index", "weight" => 0.1, "lookback" => 8, "recency" => "linear" }
        ],
        "fixture" => [
          { "metric" => "expected_goals_for", "weight" => 0.2, "lookback" => 6 }
        ],
        "availability" => { "weight" => 1.0 }
      }
    )

    # Defender: increase fixture weight from -0.4 to -0.6
    # Backtesting GW10-28: 32.4% capture vs 31.2% current (+1.2%)
    Strategy.where(position: "defender", active: true).update_all(active: false)
    Strategy.create!(
      position: "defender",
      active: true,
      strategy_config: {
        "performance" => [
          { "metric" => "clean_sheets", "weight" => 0.4, "lookback" => 8, "recency" => "linear" },
          { "metric" => "total_points", "weight" => 0.35, "lookback" => 8, "recency" => "linear" },
          { "metric" => "bonus", "weight" => 0.15, "lookback" => 6, "recency" => "linear" }
        ],
        "fixture" => [
          { "metric" => "expected_goals_against", "weight" => -0.6, "lookback" => 6 }
        ],
        "availability" => { "weight" => 1.0 }
      }
    )
  end

  def down
    Strategy.where(position: "forward", active: true).destroy_all
    Strategy.where(position: "forward", active: false)
            .order(created_at: :desc).first&.update!(active: true)

    Strategy.where(position: "defender", active: true).destroy_all
    Strategy.where(position: "defender", active: false)
            .order(created_at: :desc).first&.update!(active: true)
  end
end
