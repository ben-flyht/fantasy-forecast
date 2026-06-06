require "test_helper"

class ForecastRunTest < ActiveSupport::TestCase
  # Stand-in for a position-specific Strategy, so the fault-isolation logic can
  # be tested without the full scoring machinery.
  class FakeStrategy
    attr_reader :position

    def initialize(position:, count: 0, error: nil)
      @position = position
      @count = count
      @error = error
    end

    def position_specific?
      true
    end

    def generate_forecasts(_gameweek, generate_explanations:)
      raise @error if @error

      Array.new(@count)
    end
  end

  setup do
    # Unsaved: the fault-isolation logic never persists the gameweek, it just
    # hands it to each strategy (here a stand-in that ignores it).
    @gameweek = Gameweek.new(fpl_id: 1, name: "Gameweek 1", start_time: Time.current)
  end

  test "runs every strategy even when one raises, and reports the failure" do
    strategies = [
      FakeStrategy.new(position: "goalkeeper", count: 5),
      FakeStrategy.new(position: "defender", error: RuntimeError.new("boom")),
      FakeStrategy.new(position: "forward", count: 3)
    ]

    result = ForecastRun.call(gameweek: @gameweek, strategies: strategies)

    # The strategy after the failure still ran
    assert_equal 8, result.total_forecasts
    assert_equal [ "defender" ], result.failures.map { |outcome| outcome[:position] }
    assert_not result.ok?
  end

  test "ok? is true with no failures when every strategy succeeds" do
    strategies = [
      FakeStrategy.new(position: "goalkeeper", count: 2),
      FakeStrategy.new(position: "defender", count: 4)
    ]

    result = ForecastRun.call(gameweek: @gameweek, strategies: strategies)

    assert result.ok?
    assert_empty result.failures
    assert_equal 6, result.total_forecasts
  end
end
