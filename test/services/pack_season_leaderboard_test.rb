require "test_helper"

class PackSeasonLeaderboardTest < ActiveSupport::TestCase
  def row(accuracy, weeks, average: 0.73)
    PackSeasonLeaderboard::Row.new(place: nil, user: nil, points: 0, got: accuracy, possible: 100, pairs: weeks * 5,
                                   weeks: weeks, best: nil, real: nil, average: average)
  end

  test "the rating blends your average with the field's as if you started with two average weeks" do
    assert_equal 82, row(100, 1).rating
    assert_equal 87, row(90, 10).rating
    assert_operator row(90, 10).rating, :>, row(100, 1).rating, "a strong season beats one perfect week"
  end

  test "the same weeks and average always give the same rating" do
    a = PackSeasonLeaderboard::Row.new(place: nil, user: nil, points: 0, got: 896, possible: 1000, pairs: 50, weeks: 10, best: nil, real: nil, average: 0.73)
    b = PackSeasonLeaderboard::Row.new(place: nil, user: nil, points: 0, got: 44, possible: 49, pairs: 50, weeks: 10, best: nil, real: nil, average: 0.73)

    assert_equal [ a.accuracy, a.weeks ], [ b.accuracy, b.weeks ]
    assert_equal a.rating, b.rating
  end

  test "a manager is a Pro once their rating reaches the bar, and one perfect week is not enough" do
    assert_not row(100, 1).pro?
    assert row(94, 3).pro?
    assert row(88, 10).pro?
    assert_not row(85, 10).pro?
  end
end
