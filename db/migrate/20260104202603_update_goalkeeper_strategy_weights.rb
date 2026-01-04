class UpdateGoalkeeperStrategyWeights < ActiveRecord::Migration[8.1]
  def up
    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    return unless bot

    # Deactivate existing goalkeeper strategy
    Strategy.where(user: bot, position: "goalkeeper", active: true).update_all(active: false)

    # Create new strategy with optimized config from backtesting
    # Backtesting showed clean sheet focus (0.5 weight) and higher fixture penalty (-0.4) improves accuracy
    # Top3 hit rate: 16.7% vs 11.9% (current), Top5: 27.1% vs 25.7%
    Strategy.create!(
      user: bot,
      position: "goalkeeper",
      active: true,
      strategy_config: {
        "performance" => [
          { "metric" => "clean_sheets", "weight" => 0.5, "lookback" => 5, "recency" => "linear" },
          { "metric" => "total_points", "weight" => 0.3, "lookback" => 5, "recency" => "linear" },
          { "metric" => "saves", "weight" => 0.2, "lookback" => 5, "recency" => "linear" }
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
    Strategy.where(user: bot, position: "goalkeeper", active: true).destroy_all

    # Reactivate the previous strategy
    Strategy.where(user: bot, position: "goalkeeper", active: false)
            .order(created_at: :desc)
            .first
            &.update!(active: true)
  end
end
