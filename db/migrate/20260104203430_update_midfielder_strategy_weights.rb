class UpdateMidfielderStrategyWeights < ActiveRecord::Migration[8.1]
  def up
    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    return unless bot

    # Deactivate existing midfielder strategy
    Strategy.where(user: bot, position: "midfielder", active: true).update_all(active: false)

    # Create new strategy with optimized config from backtesting
    # Added bonus metric which improved Top5 hit rate from 35.7% to 42.9%
    Strategy.create!(
      user: bot,
      position: "midfielder",
      active: true,
      strategy_config: {
        "performance" => [
          { "metric" => "expected_goal_involvements", "weight" => 0.4, "lookback" => 5, "recency" => "exponential" },
          { "metric" => "total_points", "weight" => 0.3, "lookback" => 5, "recency" => "linear" },
          { "metric" => "bonus", "weight" => 0.2, "lookback" => 5, "recency" => "linear" },
          { "metric" => "ict_index", "weight" => 0.1, "lookback" => 5, "recency" => "linear" }
        ],
        "fixture" => [
          { "metric" => "expected_goals_for", "weight" => 0.2 }
        ],
        "availability" => { "weight" => 1.0 }
      }
    )
  end

  def down
    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    return unless bot

    # Remove the new strategy
    Strategy.where(user: bot, position: "midfielder", active: true).destroy_all

    # Reactivate the previous strategy
    Strategy.where(user: bot, position: "midfielder", active: false)
            .order(created_at: :desc)
            .first
            &.update!(active: true)
  end
end
