require "test_helper"

class TierCalculatorTest < ActiveSupport::TestCase
  def ranking(score)
    ConsensusRanking::Ranking.new(player_id: 1, score: score)
  end

  test "a single-gameweek score meets the bands directly" do
    tiers = TierCalculator.new([ ranking(4.5), ranking(2.0) ]).call.map(&:tier)
    assert_equal [ 1, 4 ], tiers
  end

  test "a season total is averaged over its gameweeks before tiering" do
    without = TierCalculator.new([ ranking(40.0) ]).call.first.tier
    with = TierCalculator.new([ ranking(40.0) ], points_divisor: 10).call.first.tier

    assert_equal 1, without, "unaveraged, a season total tops the table"
    assert_equal 2, with, "averaged to 4.0 a game it reads as a strong reliable option"
  end

  test "a missing score is snow whatever the divisor" do
    assert_equal 5, TierCalculator.new([ ranking(nil) ], points_divisor: 10).call.first.tier
  end
end
