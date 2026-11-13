require "test_helper"

class PackSeasonLeaderboardTest < ActiveSupport::TestCase
  def row(right, pairs)
    PackSeasonLeaderboard::Row.new(place: nil, user: nil, points: 0, right: right, pairs: pairs, weeks: 1, best: nil, real: nil)
  end

  test "the accuracy rating grows with the pairs called, so a perfect week trails a long good run" do
    assert_operator row(40, 50).rating, :>, row(5, 5).rating
    assert_operator row(10, 10).rating, :>, row(5, 5).rating
    assert_operator row(5, 5).rating, :>, row(4, 5).rating
    assert_equal 0, row(0, 0).rating
    assert_equal 57, row(5, 5).rating
  end

  test "a manager is a Pro once their accuracy rating reaches the bar, and one perfect week is not enough" do
    assert_not row(5, 5).pro?
    assert row(9, 10).pro?
    assert row(30, 40).pro?
    assert_not row(16, 20).pro?
  end
end
