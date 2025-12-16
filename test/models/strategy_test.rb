require "test_helper"

class StrategyTest < ActiveSupport::TestCase
  def setup
    @bot_user = create_test_bot
    @valid_config = { strategies: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ] }
  end

  test "valid strategy with config" do
    strategy = Strategy.new(
      user: @bot_user,
      description: "Test strategy",
      strategy_config: @valid_config,
      active: true
    )

    assert strategy.valid?
  end

  test "requires strategy_config to be present" do
    strategy = Strategy.new(
      user: @bot_user,
      description: "Test strategy",
      strategy_config: nil,
      active: true
    )

    assert_not strategy.valid?
    assert_includes strategy.errors[:strategy_config], "can't be nil"
  end

  test "allows duplicate strategy_config" do
    Strategy.create!(
      user: @bot_user,
      description: "First strategy",
      strategy_config: @valid_config,
      active: true
    )

    another_user = create_test_bot
    duplicate_strategy = Strategy.create!(
      user: another_user,
      description: "Duplicate strategy",
      strategy_config: @valid_config,
      active: true
    )

    assert duplicate_strategy.persisted?
  end

  test "allows updating strategy" do
    strategy = Strategy.create!(
      user: @bot_user,
      description: "Original description",
      strategy_config: @valid_config,
      active: true
    )

    strategy.description = "Updated description"
    assert strategy.valid?
    assert strategy.save
  end

  test "active scope returns only active strategies" do
    active_strategy = Strategy.create!(
      user: @bot_user,
      description: "Active",
      strategy_config: @valid_config,
      active: true
    )

    another_user = create_test_bot
    inactive_strategy = Strategy.create!(
      user: another_user,
      description: "Inactive",
      strategy_config: { strategies: [ { metric: "goals_scored", weight: 1.0, lookback: 1, recency: "none" } ] },
      active: false
    )

    active_strategies = Strategy.active

    assert_includes active_strategies, active_strategy
    assert_not_includes active_strategies, inactive_strategy
  end

  test "delegates username to user" do
    strategy = Strategy.new(user: @bot_user, strategy_config: @valid_config)

    assert_equal @bot_user.username, strategy.username
  end

  test "strategy_explanation returns description if present" do
    strategy = Strategy.new(
      user: @bot_user,
      description: "My custom description",
      strategy_config: @valid_config
    )

    assert_equal "My custom description", strategy.strategy_explanation
  end

  test "strategy_explanation generates explanation for empty config" do
    strategy = Strategy.new(
      user: @bot_user,
      description: nil,
      strategy_config: {}
    )

    assert_equal "Selects players completely at random (no strategy)", strategy.strategy_explanation
  end

  test "strategy_explanation generates explanation for single strategy with no recency" do
    strategy = Strategy.new(
      user: @bot_user,
      description: nil,
      strategy_config: { strategies: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ] }
    )

    assert_equal "Selects players based on points over the last 3 gameweeks (equal weighting)", strategy.strategy_explanation
  end

  test "strategy_explanation generates explanation for single strategy with linear recency" do
    strategy = Strategy.new(
      user: @bot_user,
      description: nil,
      strategy_config: { strategies: [ { metric: "goals_scored", weight: 1.0, lookback: 5, recency: "linear" } ] }
    )

    assert_equal "Selects players based on goals over the last 5 gameweeks, with linear weighting toward more recent matches", strategy.strategy_explanation
  end

  test "strategy_explanation generates explanation for single strategy with exponential recency" do
    strategy = Strategy.new(
      user: @bot_user,
      description: nil,
      strategy_config: { strategies: [ { metric: "expected_goals", weight: 1.0, lookback: 4, recency: "exponential" } ] }
    )

    assert_equal "Selects players based on expected goals (xG) over the last 4 gameweeks, with exponential weighting heavily favoring most recent matches", strategy.strategy_explanation
  end

  test "strategy_explanation generates explanation for composite strategy" do
    strategy = Strategy.new(
      user: @bot_user,
      description: nil,
      strategy_config: {
        strategies: [
          { metric: "total_points", weight: 0.6, lookback: 3, recency: "none" },
          { metric: "goals_scored", weight: 0.4, lookback: 5, recency: "linear" }
        ]
      }
    )

    explanation = strategy.strategy_explanation

    assert_includes explanation, "Composite strategy"
    assert_includes explanation, "60% points (3GW)"
    assert_includes explanation, "40% goals (5GW"
    assert_includes explanation, "linear recency"
  end

  test "strategy_explanation includes availability filter" do
    strategy = Strategy.new(
      user: @bot_user,
      description: nil,
      strategy_config: {
        strategies: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ],
        filters: { availability: { min_chance_of_playing: 75 } }
      }
    )

    explanation = strategy.strategy_explanation

    assert_includes explanation, "75% likely to play"
  end

  test "generate_forecasts delegates to BotForecaster" do
    # Create required test data
    team = Team.find_or_create_by!(fpl_id: 300) do |t|
      t.name = "Test Team"
      t.short_name = "TST"
    end

    # Create players for each position
    %w[goalkeeper defender midfielder forward].each_with_index do |position, i|
      slots = FantasyForecast::POSITION_CONFIG[position][:slots]
      slots.times do |j|
        Player.find_or_create_by!(fpl_id: 3000 + i * 100 + j) do |p|
          p.first_name = "Test"
          p.last_name = "#{position.capitalize}#{j}"
          p.position = position
          p.team = team
        end
      end
    end

    # Create gameweeks
    finished_gw = Gameweek.find_or_create_by!(fpl_id: 300) do |gw|
      gw.name = "Gameweek 300"
      gw.start_time = 2.weeks.ago
      gw.is_finished = true
    end

    next_gw = Gameweek.find_or_create_by!(fpl_id: 301) do |gw|
      gw.name = "Gameweek 301"
      gw.start_time = 1.day.from_now
      gw.is_next = true
      gw.is_finished = false
    end

    # Create statistics for players
    Player.where(position: "midfielder").each do |player|
      Statistic.find_or_create_by!(player: player, gameweek: finished_gw, type: "total_points") do |s|
        s.value = rand(1..15)
      end
    end

    strategy = Strategy.create!(
      user: @bot_user,
      description: "Test strategy",
      strategy_config: { strategies: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ] },
      active: true
    )

    forecasts = strategy.generate_forecasts(next_gw)

    # Bot now creates forecasts for ALL players (for rankings), not just slot count
    expected_total = Player.count
    assert_equal expected_total, forecasts.count
    assert forecasts.all? { |f| f.user == @bot_user }
    assert forecasts.all? { |f| f.gameweek == next_gw }
    assert forecasts.all? { |f| f.rank.present? }, "All forecasts should have ranks"
  end
end
