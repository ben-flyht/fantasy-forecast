require "test_helper"

class StrategyTest < ActiveSupport::TestCase
  def setup
    @valid_config = { strategies: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ] }
  end

  test "valid strategy with config" do
    strategy = Strategy.new(strategy_config: @valid_config)

    assert strategy.valid?
  end

  test "requires strategy_config to be present" do
    strategy = Strategy.new(strategy_config: nil)

    assert_not strategy.valid?
    assert_includes strategy.errors[:strategy_config], "can't be nil"
  end

  # Two forecasts made with the same settings are looked up, not rejected, so
  # nothing here may stop the same set of parameters being written twice.
  test "allows duplicate strategy_config" do
    Strategy.create!(strategy_config: @valid_config)

    duplicate_strategy = Strategy.create!(strategy_config: @valid_config)

    assert duplicate_strategy.persisted?
  end
end
