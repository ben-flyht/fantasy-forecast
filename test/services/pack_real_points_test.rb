require "test_helper"

class PackRealPointsTest < ActiveSupport::TestCase
  setup do
    @gameweek = Gameweek.create!(fpl_id: 31, name: "Gameweek 31", start_time: 1.day.ago)
    team = Team.create!(fpl_id: 931, code: 931, name: "Verdict Town", short_name: "VDT")
    @late = Team.create!(fpl_id: 932, code: 932, name: "Late Kick", short_name: "LTK")
    @rival = Team.create!(fpl_id: 933, code: 933, name: "Rival", short_name: "RVL")
    @cards = [ 8, 3, 3 ].each_with_index.map do |points, i|
      player = Player.create!(first_name: "P", last_name: "v#{i}", fpl_id: 93_100 + i, code: 93_100 + i, team: team, position: "midfielder")
      Performance.create!(player: player, gameweek: @gameweek, team: team, gameweek_score: points)
      Pack::Card.new(player: player, rank: i + 1, expected_points: 4.0)
    end
    @real = PackRealPoints.new(@gameweek)
  end

  test "a pick is better, level or worse against the card let go, and a missing pick is no pick" do
    high, low, same = @cards

    assert_equal :better, @real.verdict(high, [ low ])
    assert_equal :level, @real.verdict(low, [ same ])
    assert_equal :worse, @real.verdict(low, [ high ])
    assert_equal :no_pick, @real.verdict(nil, [])
  end

  test "a pair is not called until every match for both cards' teams has finished" do
    high, low, = @cards
    match = Match.create!(gameweek: @gameweek, home_team: @late, away_team: @rival, fpl_id: 93_201)
    later = Pack::Card.new(player: Player.create!(first_name: "P", last_name: "late", fpl_id: 93_200, code: 93_200, team: @late, position: "midfielder"),
                           rank: 4, expected_points: 4.0)

    assert_equal :pending, PackRealPoints.new(@gameweek).verdict(high, [ later ])
    assert_equal :pending, PackRealPoints.new(@gameweek).verdict(later, [ low ])
    assert_equal :better, PackRealPoints.new(@gameweek).verdict(high, [ low ])

    match.update!(finished: true)
    assert_equal :better, PackRealPoints.new(@gameweek).verdict(high, [ later ])
  end

  def card_scoring(points, index, team: Team.find_by(fpl_id: 931))
    player = Player.create!(first_name: "P", last_name: "t#{index}", fpl_id: 93_300 + index, code: 93_300 + index, team: team, position: "midfielder")
    Performance.create!(player: player, gameweek: @gameweek, team: team, gameweek_score: points)
    Pack::Card.new(player: player, rank: index, expected_points: 4.0)
  end

  def pack_of(*pairs, shiny: nil)
    Pack.new(pairs: pairs.each_with_index.map { |cards, i| Pack::Pair.new(slot: Pack::SLOTS[i], cards: cards, shiny: i == shiny) })
  end

  test "accuracy is the share of the points on offer that was scored, so a big miss costs more than a near one" do
    near = [ card_scoring(2, 1), card_scoring(3, 2) ]
    big = [ card_scoring(2, 3), card_scoring(12, 4) ]
    captain = [ card_scoring(6, 5), card_scoring(1, 6) ]
    negative = [ card_scoring(-2, 7), card_scoring(-1, 8) ]
    skipped = [ card_scoring(5, 9), card_scoring(4, 10) ]
    hand = PackHand.parse(pack_of(near, big, captain, negative, skipped, shiny: 2), "aaaax")

    tally = PackRealPoints.new(@gameweek).tally(hand)

    assert_equal 2 + 2 + 12 + 0 + 0, tally.got
    assert_equal 3 + 12 + 12 + 0 + 5, tally.possible
    assert_equal 5, tally.pairs
  end

  test "a pair still being played is left out of accuracy until it is decided" do
    Match.create!(gameweek: @gameweek, home_team: @late, away_team: @rival, fpl_id: 93_401)
    done = [ card_scoring(5, 11), card_scoring(1, 12) ]
    live = [ card_scoring(0, 13, team: @late), card_scoring(9, 14) ]
    hand = PackHand.parse(pack_of(done, live), "aa")

    tally = PackRealPoints.new(@gameweek).tally(hand)

    assert_equal [ 5, 5, 1 ], [ tally.got, tally.possible, tally.pairs ]
  end
end
