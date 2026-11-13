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
end
