class UpdateDefenderStrategyLookbacks < ActiveRecord::Migration[8.1]
  def up
    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    return unless bot

    # Deactivate existing defender strategy
    Strategy.where(user: bot, position: "defender", active: true).update_all(active: false)

    # Create new strategy with longer lookback windows from backtesting
    # Backtesting showed 8/8/6 lookbacks improved top-3 accuracy by +25 pts over 10 GWs
    Strategy.create!(
      user: bot,
      position: "defender",
      active: true,
      strategy_config: {
        "performance" => [
          { "metric" => "clean_sheets", "weight" => 0.4, "lookback" => 8, "recency" => "linear" },
          { "metric" => "total_points", "weight" => 0.35, "lookback" => 8, "recency" => "linear" },
          { "metric" => "bonus", "weight" => 0.15, "lookback" => 6, "recency" => "linear" }
        ],
        "fixture" => [
          { "metric" => "expected_goals_against", "weight" => -0.4 }
        ],
        "availability" => { "weight" => 1.0 }
      }
    )
  end

  def down
    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    return unless bot

    # Remove the new strategy
    Strategy.where(user: bot, position: "defender", active: true).destroy_all

    # Reactivate the previous strategy
    Strategy.where(user: bot, position: "defender", active: false)
            .order(created_at: :desc)
            .first
            &.update!(active: true)
  end
end
