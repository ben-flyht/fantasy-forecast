class SetupFantasyForecasterBot < ActiveRecord::Migration[8.0]
  def up
    # Delete all existing bots (except ForecasterBot if it exists)
    old_bots = User.where(bot: true).where.not(username: User::BOT_USERNAME)
    Forecast.where(user: old_bots).delete_all
    Strategy.where(user: old_bots).delete_all
    old_bots.delete_all

    bot = User.find_by(username: User::BOT_USERNAME, bot: true)
    unless bot
      bot = User.new(username: User::BOT_USERNAME, bot: true)
      bot.save!(validate: false)  # Skip email/password validations
    end

    strategies = {
      "goalkeeper" => {
        strategies: [
          { metric: "total_points", weight: 0.4, lookback: 5, recency: "linear" },
          { metric: "saves", weight: 0.3, lookback: 5, recency: "linear" },
          { metric: "clean_sheets", weight: 0.3, lookback: 5, recency: "linear" }
        ],
        fixture_strategies: [
          { metric: "expected_goals_against", weight: -0.2 }
        ],
        filters: { availability: { min_chance_of_playing: 75 } }
      },
      "defender" => {
        strategies: [
          { metric: "total_points", weight: 0.5, lookback: 5, recency: "linear" },
          { metric: "clean_sheets", weight: 0.3, lookback: 5, recency: "linear" },
          { metric: "bonus", weight: 0.2, lookback: 5, recency: "linear" }
        ],
        fixture_strategies: [
          { metric: "expected_goals_against", weight: -0.3 }
        ],
        filters: { availability: { min_chance_of_playing: 75 } }
      },
      "midfielder" => {
        strategies: [
          { metric: "expected_goal_involvements", weight: 0.5, lookback: 5, recency: "exponential" },
          { metric: "total_points", weight: 0.3, lookback: 5, recency: "linear" },
          { metric: "ict_index", weight: 0.2, lookback: 5, recency: "linear" }
        ],
        fixture_strategies: [
          { metric: "expected_goals_for", weight: 0.2 }
        ],
        filters: { availability: { min_chance_of_playing: 75 } }
      },
      "forward" => {
        strategies: [
          { metric: "expected_goals", weight: 0.5, lookback: 3, recency: "exponential" },
          { metric: "goals_scored", weight: 0.3, lookback: 5, recency: "linear" },
          { metric: "ict_index", weight: 0.2, lookback: 3, recency: "linear" }
        ],
        fixture_strategies: [
          { metric: "expected_goals_for", weight: 0.3 }
        ],
        filters: { availability: { min_chance_of_playing: 75 } }
      }
    }

    strategies.each do |position, config|
      Strategy.find_or_create_by!(user: bot, position: position) do |s|
        s.strategy_config = config
        s.active = true
      end
    end
  end

  def down
    # Data migration - no rollback needed
  end
end
