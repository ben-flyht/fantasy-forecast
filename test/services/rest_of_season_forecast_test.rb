require "test_helper"

class RestOfSeasonForecastTest < ActiveSupport::TestCase
  setup do
    Forecast.destroy_all
    Strategy.destroy_all
    Gameweek.destroy_all
    @team = Team.create!(fpl_id: 800, name: "Test City", short_name: "TCY", code: 800)
    @opponent = Team.create!(fpl_id: 801, name: "Test Rovers", short_name: "TRV", code: 801)
    @next = Gameweek.create!(fpl_id: 80, name: "Gameweek 80", start_time: 2.days.from_now, is_next: true)
    @later = Gameweek.create!(fpl_id: 81, name: "Gameweek 81", start_time: 9.days.from_now)
    @finished = Gameweek.create!(fpl_id: 79, name: "Gameweek 79", start_time: 5.days.ago, is_finished: true)
    Match.create!(gameweek: @next, home_team: @team, away_team: @opponent,
                  fpl_id: 8000, home_difficulty: 2, away_difficulty: 4)
    Match.create!(gameweek: @later, home_team: @team, away_team: @opponent,
                  fpl_id: 8001, home_difficulty: 2, away_difficulty: 4)
    @player = player_with_record
  end

  def player_with_record(fpl_id: 8100)
    player = Player.create!(first_name: "Test", last_name: "Player#{fpl_id}", short_name: "T#{fpl_id}",
                            fpl_id: fpl_id, code: fpl_id, team: @team, position: "forward")
    {
      "last_season_minutes" => 3000.0, "season_minutes" => 3000.0, "expected_goals_per_90" => 0.5,
      "expected_goal_involvements_per_90" => 0.7, "selected_by_percent" => 10.0, "now_cost" => 80.0
    }.each { |type, value| Statistic.create!(player: player, gameweek: @next, type: type, value: value) }
    player
  end

  test "writes a rest-of-season forecast anchored to the next gameweek" do
    RestOfSeasonForecast.call(gameweek: @next)

    forecast = Forecast.find_by(player: @player, horizon: "rest_of_season")
    assert_equal @next.id, forecast.gameweek_id, "the season total is anchored to the next gameweek"
    assert forecast.score.to_f.positive?
    assert_equal 1, forecast.rank
  end

  test "spans every remaining gameweek, so it outscores the single coming week" do
    WeeklyForecast.call(gameweek: @next)
    RestOfSeasonForecast.call(gameweek: @next)

    weekly = Forecast.find_by(player: @player, horizon: "gameweek").score
    season = Forecast.find_by(player: @player, horizon: "rest_of_season").score

    assert_operator season, :>, weekly, "two games ahead is worth more than one"
  end

  test "the two horizons sit side by side against the same gameweek" do
    WeeklyForecast.call(gameweek: @next)
    RestOfSeasonForecast.call(gameweek: @next)

    horizons = Forecast.where(player: @player, gameweek: @next).pluck(:horizon).sort
    assert_equal %w[gameweek rest_of_season], horizons
  end

  test "excludes gameweeks already finished from the horizon" do
    Match.create!(gameweek: @finished, home_team: @team, away_team: @opponent,
                  fpl_id: 7900, home_difficulty: 2, away_difficulty: 4)

    assert_equal [ 80, 81 ], Gameweek.remaining.pluck(:fpl_id)
  end

  test "refuses to write a position it cannot score anybody in" do
    Match.destroy_all

    assert_not RestOfSeasonForecast.call(gameweek: @next)
    assert_equal 0, Forecast.where(horizon: "rest_of_season").count
  end
end
