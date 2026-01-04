class UpdateForwardStrategyLookbacks < ActiveRecord::Migration[8.1]
  def up
    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    return unless bot

    # Deactivate existing forward strategy
    Strategy.where(user: bot, position: "forward", active: true).update_all(active: false)

    # Create new strategy with longer lookback windows from backtesting
    # Backtesting showed longer lookbacks (xG:6, goals:8, ict:5) better rank premium players
    Strategy.create!(
      user: bot,
      position: "forward",
      active: true,
      strategy_config: {
        "performance" => [
          { "metric" => "expected_goals", "weight" => 0.5, "lookback" => 6, "recency" => "exponential" },
          { "metric" => "goals_scored", "weight" => 0.3, "lookback" => 8, "recency" => "linear" },
          { "metric" => "ict_index", "weight" => 0.2, "lookback" => 5, "recency" => "linear" }
        ],
        "fixture" => [
          { "metric" => "expected_goals_for", "weight" => 0.3 }
        ],
        "availability" => { "weight" => 1.0 }
      }
    )
  end

  def down
    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    return unless bot

    # Remove the new strategy
    Strategy.where(user: bot, position: "forward", active: true).destroy_all

    # Reactivate the previous strategy
    Strategy.where(user: bot, position: "forward", active: false)
            .order(created_at: :desc)
            .first
            &.update!(active: true)
  end
end
