require "test_helper"

class PackRealPointsTest < ActiveSupport::TestCase
  setup do
    @gameweek = Gameweek.create!(fpl_id: 31, name: "Gameweek 31", start_time: 1.day.ago)
    team = Team.create!(fpl_id: 931, code: 931, name: "Verdict Town", short_name: "VDT")
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
end
