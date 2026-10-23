require "test_helper"

class PackScoreTest < ActiveSupport::TestCase
  def card(id, position, points)
    Pack::Card.new(player: Player.new(id: id, position: position), rank: id, expected_points: points)
  end

  setup do
    cards = [
      [ card(1, "goalkeeper", 4.0), card(2, "goalkeeper", 3.0) ],
      [ card(3, "defender", 4.0), card(4, "defender", 3.0) ],
      [ card(5, "midfielder", 6.0), card(6, "midfielder", 5.0) ],
      [ card(7, "forward", 5.5), card(8, "forward", 5.0) ],
      [ card(9, "midfielder", 3.0), card(10, "midfielder", 2.0) ]
    ]
    pairs = Pack::SLOTS.each_with_index.map { |slot, i| Pack::Pair.new(slot: slot, cards: cards[i], shiny: i == 2) }
    @pack = Pack.new(seed: 1, pairs: pairs)
    @score = PackScore.new(@pack)
  end

  test "the forecast keeps the higher card of every pair" do
    assert_equal [ 1, 3, 5, 7, 9 ], @score.forecast.kept.map(&:player_id)
  end

  test "agreement is how many of the forecast's picks you kept" do
    assert_equal 5, @score.agreements(PackHand.parse(@pack, "aaaaa"))
    assert_equal 3, @score.agreements(PackHand.parse(@pack, "abaab"))
    assert_equal 0, @score.agreements(PackHand.parse(@pack, "bbbbb"))
  end
end
