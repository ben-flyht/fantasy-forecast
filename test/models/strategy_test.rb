require "test_helper"

class StrategyTest < ActiveSupport::TestCase
  def setup
    @valid_config = { strategies: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ] }
  end

  test "valid strategy with config" do
    strategy = Strategy.new(
      strategy_config: @valid_config,
      active: true
    )

    assert strategy.valid?
  end

  test "requires strategy_config to be present" do
    strategy = Strategy.new(
      strategy_config: nil,
      active: true
    )

    assert_not strategy.valid?
    assert_includes strategy.errors[:strategy_config], "can't be nil"
  end

  test "allows duplicate strategy_config" do
    Strategy.create!(
      strategy_config: @valid_config,
      active: true
    )

    duplicate_strategy = Strategy.create!(
      strategy_config: @valid_config,
      active: true
    )

    assert duplicate_strategy.persisted?
  end

  test "allows updating strategy" do
    strategy = Strategy.create!(
      strategy_config: @valid_config,
      active: true
    )

    strategy.active = false
    assert strategy.valid?
    assert strategy.save
  end
end
