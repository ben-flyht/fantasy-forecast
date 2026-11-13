require "test_helper"

class PackSeasonLeaderboardTest < ActiveSupport::TestCase
  def row(got, possible, average: 0.7)
    PackSeasonLeaderboard::Row.new(place: nil, user: nil, points: 0, got: got, possible: possible, pairs: 5,
                                   weeks: 1, best: nil, real: nil, average: average)
  end

  test "the rating is accuracy pulled towards the field average until there are enough points on offer" do
    assert_operator row(37, 37).rating, :>, row(18, 18).rating, "a bigger perfect week is surer"
    assert_operator row(140, 160).rating, :>, row(37, 37).rating, "a strong season beats one perfect week"
    assert_equal 70, row(0, 0).rating, "with nothing on offer you sit at the average"
    assert_in_delta row(900, 1000).accuracy, row(900, 1000).rating, 2, "with plenty on offer it is your accuracy"
  end

  test "a manager is a Pro once their rating reaches the bar, and one perfect week is not enough" do
    assert_not row(37, 37).pro?
    assert row(150, 160).pro?
    assert_not row(100, 160).pro?
  end
end
