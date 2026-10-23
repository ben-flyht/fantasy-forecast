require "test_helper"

class PackHandTest < ActiveSupport::TestCase
  def card(id, position, points)
    Pack::Card.new(player: Player.new(id: id, position: position), rank: id, expected_points: points)
  end

  def pack(shiny: 2)
    cards = [
      [ card(1, "goalkeeper", 4.0), card(2, "goalkeeper", 3.0) ],
      [ card(3, "defender", 4.0), card(4, "defender", 3.0) ],
      [ card(5, "midfielder", 6.0), card(6, "midfielder", 5.0) ],
      [ card(7, "forward", 5.5), card(8, "forward", 5.0) ],
      [ card(9, "midfielder", 3.0), card(10, "midfielder", 2.0) ]
    ]
    pairs = Pack::SLOTS.each_with_index.map { |slot, i| Pack::Pair.new(slot: slot, cards: cards[i], shiny: i == shiny) }
    Pack.new(pairs: pairs)
  end

  test "a code reads back as the cards it kept, and every one of them starts" do
    hand = PackHand.parse(pack, "abaab")

    assert hand.complete?
    assert_equal [ 1, 4, 5, 7, 10 ], hand.kept.map(&:player_id)
    assert_equal "abaab", hand.code
  end

  test "the card kept from the shiny pair is the captain" do
    assert_equal 6, PackHand.parse(pack, "aab").captain.player_id
    assert_nil PackHand.parse(pack, "aa").captain
  end

  test "a hand is unfinished until all five are kept" do
    assert_not PackHand.parse(pack, "aaa").complete?
    assert_equal pack.pairs[3], PackHand.parse(pack, "aaa").current_pair
  end

  test "a code that is not a pack's is refused" do
    assert_nil PackHand.parse(pack, "aaaaaa"), "more picks than pairs"
    assert_nil PackHand.parse(pack, "aac"), "not a choice"
    assert_nil PackHand.parse(pack, "aaaaa-12"), "the old bench suffix"
  end

  test "a pair left too long is forfeited, and kept as an empty slot" do
    hand = PackHand.parse(pack, "axb")

    assert_equal [ 1, nil, 6 ], hand.picks.map { |card| card&.player_id }
    assert_equal [ 1, 6 ], hand.kept.map(&:player_id)
    assert_equal "axb", hand.code
    assert_equal "axbx", hand.forfeiting.code
  end

  test "forfeiting the shiny pair leaves you without a captain" do
    assert_nil PackHand.parse(pack, "aax").captain
    assert PackHand.parse(pack, "aaxaa").complete?
  end
end
