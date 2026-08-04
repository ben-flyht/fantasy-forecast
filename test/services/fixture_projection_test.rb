require "test_helper"

class FixtureProjectionTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(fpl_id: 900, name: "Test City", short_name: "TCY", code: 900)
    @opponent = Team.create!(fpl_id: 901, name: "Test Rovers", short_name: "TRV", code: 901)
    @next_gameweek = Gameweek.create!(fpl_id: 90, name: "Gameweek 90", start_time: 2.days.from_now, is_next: true)
    @later = Gameweek.create!(fpl_id: 91, name: "Gameweek 91", start_time: 9.days.from_now)
    @player = Player.create!(first_name: "Test", last_name: "Keeper", short_name: "TK",
                             fpl_id: 9100, code: 9100, team: @team, position: "goalkeeper")
    {
      "last_season_minutes" => 3000.0, "last_season_saves_per_90" => 3.0,
      "last_season_clean_sheets_per_90" => 0.3, "selected_by_percent" => 5.0, "now_cost" => 50.0
    }.each { |type, value| Statistic.create!(player: @player, gameweek: @next_gameweek, type: type, value: value) }
    @match = Match.create!(gameweek: @later, home_team: @team, away_team: @opponent,
                           fpl_id: 9001, home_difficulty: 2, away_difficulty: 4)
  end

  def anchor(score, games)
    Forecast.new(player: @player, gameweek: @next_gameweek, score: score, working: { "games" => games })
  end

  def project(anchors)
    FixtureProjection.call(player: @player, matches: [ @match ], anchors: anchors,
                           next_gameweek_id: @next_gameweek.id)
  end

  test "a run of fixtures is projected from the week's own forecast" do
    rows = project([ anchor(4.4, 1.1), anchor(150.0, 38.0) ])

    assert rows.first.points.positive?
    assert rows.first.projected, "a later gameweek is a projection, not a forecast"
  end

  test "a team blanking this week still shows what the fixtures after it are worth" do
    blank = anchor(0.0, 0.0)

    assert_nil project([ blank ]).first.points, "there is nothing in a blank week to anchor to"
    assert project([ blank, anchor(150.0, 38.0) ]).first.points.positive?,
           "so the season, which spans the football he does play, answers instead"
  end

  test "a player with nothing forecast at all is left blank rather than guessed at" do
    assert_nil project([]).first.points
    assert_nil project([ anchor(nil, 1.0) ]).first.points
  end
end
