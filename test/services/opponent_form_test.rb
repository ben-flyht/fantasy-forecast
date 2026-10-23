require "test_helper"

class OpponentFormTest < ActiveSupport::TestCase
  def meeting(home, away, home_xg, away_xg)
    { home: home, away: away, home_xg: home_xg, away_xg: away_xg }
  end

  def season(games)
    games.times.flat_map do
      [ meeting(1, 2, 2.0, 2.0), meeting(3, 4, 1.0, 1.0), meeting(3, 1, 1.5, 1.5), meeting(4, 2, 1.5, 1.5) ]
    end
  end

  test "with no football played there is nothing to say" do
    assert_equal({}, OpponentForm.new([]).ratings(1, 3))
  end

  test "an unknown opponent is left to FDR" do
    assert_equal({}, OpponentForm.new(season(1)).ratings(nil, 3))
  end

  test "a side shipping chances is easier to attack and a side making them is harder to keep out" do
    form = OpponentForm.new(season(5))
    open_side = form.ratings(1, 3)
    tight_side = form.ratings(3, 3)

    assert_operator open_side[:attack], :<, 3
    assert_operator open_side[:defence], :>, 3
    assert_operator tight_side[:attack], :>, 3
    assert_operator tight_side[:defence], :<, 3
  end

  test "FDR keeps three quarters of the say" do
    form = OpponentForm.new(season(1000))
    conceded, = form.rates(1)
    pure = ExpectedPoints::AVERAGE_DIFFICULTY - (conceded - 1.5) / OpponentForm::XG_SPREAD

    assert_in_delta 0.25 * pure + 0.75 * 4, form.ratings(1, 4)[:attack], 0.001
  end

  test "a few matches are pulled towards the league average" do
    early, = OpponentForm.new(season(1)).rates(1)
    late, = OpponentForm.new(season(20)).rates(1)

    assert_operator early, :<, late
    assert_in_delta 1.75, late, 0.05
  end

  test "an unrated fixture is read as an ordinary one" do
    form = OpponentForm.new(season(5))

    assert_equal form.ratings(1, ExpectedPoints::AVERAGE_DIFFICULTY), form.ratings(1, nil)
  end

  test "reads each side's expected goals from finished gameweeks before the one forecast" do
    home = Team.create!(fpl_id: 950, name: "Form City", short_name: "FMC", code: 950)
    away = Team.create!(fpl_id: 951, name: "Form Rovers", short_name: "FMR", code: 951)
    played = Gameweek.create!(fpl_id: 95, name: "Gameweek 95", start_time: 9.days.ago, is_finished: true)
    upcoming = Gameweek.create!(fpl_id: 96, name: "Gameweek 96", start_time: 2.days.from_now, is_next: true)
    later = Gameweek.create!(fpl_id: 97, name: "Gameweek 97", start_time: 9.days.from_now, is_finished: true)
    [ played, later ].each_with_index do |gameweek, index|
      Match.create!(gameweek: gameweek, home_team: home, away_team: away, fpl_id: 9500 + index)
    end
    { home => 2.4, away => 0.6 }.each_with_index do |(team, xg), index|
      player = Player.create!(first_name: "Form", last_name: "P#{index}", short_name: "F#{index}",
                              fpl_id: 9600 + index, code: 9600 + index, team: team, position: "forward")
      [ played, later ].each do |gameweek|
        Performance.create!(player: player, gameweek: gameweek, team: team, gameweek_score: 2)
        Statistic.create!(player: player, gameweek: gameweek, type: "expected_goals", value: xg)
      end
    end

    meetings = OpponentForm.played_meetings(Gameweek.where(fpl_id: ...upcoming.fpl_id))

    assert_equal [ { home: home.id, away: away.id, home_xg: 2.4, away_xg: 0.6 } ], meetings
    assert_operator OpponentForm.before(upcoming).ratings(away.id, 3)[:attack], :<, 3
  end
end
