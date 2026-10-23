require "test_helper"

class PackScoreTest < ActiveSupport::TestCase
  def card(id, position, points)
    PickablePool::Candidate.new(player: Player.new(id: id, position: position), rank: id, cost: 50, expected_points: points)
  end

  setup do
    cards = [
      [ card(1, "goalkeeper", 4.0), card(2, "goalkeeper", 3.0) ],
      [ card(3, "defender", 4.0), card(4, "defender", 3.0) ],
      [ card(5, "defender", 3.5), card(6, "defender", 2.5) ],
      [ card(7, "midfielder", 6.0), card(8, "midfielder", 5.0) ],
      [ card(9, "midfielder", 4.5), card(10, "midfielder", 4.0) ],
      [ card(11, "forward", 5.5), card(12, "forward", 5.0) ],
      [ card(13, "midfielder", 3.0), card(14, "midfielder", 2.0) ]
    ]
    pairs = Pack::SLOTS.each_with_index.map { |slot, i| Pack::Pair.new(slot: slot, cards: cards[i], shiny: i == 3) }
    @pack = Pack.new(seed: 1, pairs: pairs)
    @score = PackScore.new(@pack)
  end

  test "five start in full, the captain counts twice and the bench by how often it comes on" do
    hand = PackHand.parse(@pack, "aaaaaaa-26")
    first, second = PackScore::BENCH_WEIGHTS

    expected = (4.0 + 4.0 + 6.0 + 4.5 + 5.5) + 6.0 + (3.5 * first) + (3.0 * second)
    assert_in_delta expected, @score.points(hand), 0.0001
  end

  test "the forecast keeps the higher card of every pair and plays its best line-up" do
    assert_equal [ 1, 3, 5, 7, 9, 11, 13 ], @score.forecast.kept.map(&:player_id)
    assert_equal [ 5, 13 ], @score.forecast.substitutes.map(&:player_id)
  end

  test "nobody beats the perfect pack" do
    worst = PackHand.parse(@pack, "bbbbbbb-26")

    assert_operator @score.points(@score.perfect), :>=, @score.points(@score.forecast)
    assert_in_delta 1.0, @score.share(@score.forecast), 0.0001
    assert_operator @score.share(worst), :<, 1.0
  end
end
