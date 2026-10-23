require "test_helper"

class PackHandTest < ActiveSupport::TestCase
  def card(id, position, points)
    PickablePool::Candidate.new(player: Player.new(id: id, position: position), rank: id, cost: 50, expected_points: points)
  end

  def pack(shiny: 0)
    cards = [
      [ card(1, "goalkeeper", 4.0), card(2, "goalkeeper", 3.0) ],
      [ card(3, "defender", 4.0), card(4, "defender", 3.0) ],
      [ card(5, "defender", 3.5), card(6, "defender", 2.5) ],
      [ card(7, "midfielder", 6.0), card(8, "midfielder", 5.0) ],
      [ card(9, "midfielder", 4.5), card(10, "midfielder", 4.0) ],
      [ card(11, "forward", 5.5), card(12, "forward", 5.0) ],
      [ card(13, "midfielder", 3.0), card(14, "midfielder", 2.0) ]
    ]
    pairs = Pack::SLOTS.each_with_index.map { |slot, i| Pack::Pair.new(slot: slot, cards: cards[i], shiny: i == shiny) }
    Pack.new(seed: 1, pairs: pairs)
  end

  test "a code reads back as the cards it kept and the bench it named" do
    hand = PackHand.parse(pack, "abaaaab-14")

    assert hand.complete?
    assert_equal [ 1, 4, 5, 7, 9, 11, 14 ], hand.kept.map(&:player_id)
    assert_equal [ 4, 9 ], hand.substitutes.map(&:player_id)
    assert_equal "abaaaab-14", hand.code
  end

  test "the card kept from the shiny pair is the captain" do
    hand = PackHand.parse(pack(shiny: 3), "aaab")

    assert_equal 8, hand.captain.player_id
  end

  test "a hand is picking until all seven are kept, then benching until two sit down" do
    assert PackHand.parse(pack, "aaa").picking?
    assert PackHand.parse(pack, "aaaaaaa").benching?
    assert PackHand.parse(pack, "aaaaaaa-1").benching?
  end

  test "the keeper, the captain and the last of a position cannot be benched" do
    hand = PackHand.parse(pack(shiny: 3), "aaaaaaa")

    assert_not hand.benchable?(0), "the only keeper"
    assert_not hand.benchable?(3), "the captain"
    assert_not hand.benchable?(5), "the only forward"
    assert hand.benchable?(1)
  end

  test "a code that breaks the rules is refused" do
    assert_nil PackHand.parse(pack, "aaaaaaa-12"), "no defender left starting"
    assert_nil PackHand.parse(pack, "aaaaaaa-0"), "the keeper benched"
    assert_nil PackHand.parse(pack, "aaaaaaa-11"), "the same card benched twice"
    assert_nil PackHand.parse(pack, "aa-1"), "a bench before the picks are done"
    assert_nil PackHand.parse(pack, "aaaaaaaa"), "more picks than pairs"
  end

  test "every line-up a pack allows is every keep with every legal bench" do
    line_ups = PackHand.every_line_up(pack(shiny: 3))

    assert line_ups.all?(&:complete?)
    assert_equal line_ups.map(&:code).uniq.size, line_ups.size
    assert_includes line_ups.map(&:code), "aaaaaaa-26"
  end
end
