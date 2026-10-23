require "test_helper"

class RankMovementComponentTest < ViewComponent::TestCase
  History = Struct.new(:ranks, :rank_change)
  Point = Struct.new(:gameweek, :value, keyword_init: true)

  def history(*ranks)
    points = ranks.each_with_index.map { |rank, index| Point.new(gameweek: 6 + index, value: rank) }
    History.new(points, (points[-2].value - points[-1].value if points.many?))
  end

  test "a climb says how far, and since when, in words" do
    render_inline RankMovementComponent.new(history: history(26, 12))

    assert_text "Up 14 places since GW6"
  end

  test "a fall says so plainly" do
    render_inline RankMovementComponent.new(history: history(4, 5))

    assert_text "Down 1 place since GW6"
  end

  test "no movement is said as the same as last time" do
    render_inline RankMovementComponent.new(history: history(9, 9))

    assert_text "Same as GW6"
  end

  test "one week is not a movement" do
    render_inline RankMovementComponent.new(history: history(9))

    assert_no_text "since"
  end
end
