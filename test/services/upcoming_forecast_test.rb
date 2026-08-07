require "test_helper"

# The horizon a transfer is actually made over. What matters here is that it reads the
# run of fixtures in front of it and no further: a five-week forecast that quietly
# spanned the season would be the season forecast under another name.
class UpcomingForecastTest < ActiveSupport::TestCase
  setup do
    Forecast.destroy_all
    Strategy.destroy_all
    Gameweek.destroy_all
    Match.destroy_all

    @team = Team.create!(fpl_id: 810, name: "Test City", short_name: "TCY", code: 810)
    @opponent = Team.create!(fpl_id: 811, name: "Test Rovers", short_name: "TRV", code: 811)

    # Ten weeks of football, so the window has somewhere to stop short of.
    @weeks = (1..10).map do |n|
      week = Gameweek.create!(fpl_id: n, name: "Gameweek #{n}", start_time: n.days.from_now, is_next: n == 1)
      Match.create!(gameweek: week, home_team: @team, away_team: @opponent,
                    fpl_id: 8_200 + n, home_difficulty: 2, away_difficulty: 4)
      week
    end
    @player = player_with_record
  end

  def player_with_record(fpl_id: 8300)
    player = Player.create!(first_name: "Test", last_name: "Player#{fpl_id}", short_name: "T#{fpl_id}",
                            fpl_id: fpl_id, code: fpl_id, team: @team, position: "forward")
    {
      "last_season_minutes" => 3000.0, "season_minutes" => 3000.0,
      "last_season_expected_goals_per_90" => 0.5, "expected_goals_per_90" => 0.5,
      "last_season_expected_goal_involvements_per_90" => 0.7,
      "expected_goal_involvements_per_90" => 0.7, "selected_by_percent" => 10.0, "now_cost" => 80.0
    }.each { |type, value| Statistic.create!(player: player, gameweek: @weeks.first, type: type, value: value) }
    player
  end

  test "it stores against the coming gameweek, under its own horizon" do
    UpcomingForecast.call(gameweek: @weeks.first)

    forecast = Forecast.find_by(player: @player, horizon: "upcoming")
    assert_not_nil forecast
    assert_equal @weeks.first, forecast.gameweek
  end

  # The whole point of the horizon: it stops at the window, so it lands between the
  # single week and the whole season rather than beside either.
  test "it spans the window and no further" do
    WeeklyForecast.call(gameweek: @weeks.first)
    UpcomingForecast.call(gameweek: @weeks.first)
    SeasonForecast.call(gameweek: @weeks.first)

    scores = %w[gameweek upcoming season].index_with do |horizon|
      Forecast.find_by(player: @player, horizon: horizon).score.to_f
    end

    assert_operator scores["upcoming"], :>, scores["gameweek"]
    assert_operator scores["upcoming"], :<, scores["season"]
  end

  # Five fixtures rather than five times one: the same arithmetic the other horizons
  # use, over a different run, which is what lets a kind or cruel run show up at all.
  test "its total is about the window's worth of the coming week" do
    WeeklyForecast.call(gameweek: @weeks.first)
    UpcomingForecast.call(gameweek: @weeks.first)

    weekly = Forecast.find_by(player: @player, horizon: "gameweek").score.to_f
    upcoming = Forecast.find_by(player: @player, horizon: "upcoming").score.to_f

    assert_in_delta weekly * Horizon::WINDOW, upcoming, weekly * Horizon::WINDOW * 0.35
  end

  # In May there is no five-week run left, and the horizon has to mean whatever is
  # actually there rather than refusing or reaching for weeks that do not exist.
  test "a season with less football left than the window forecasts what is there" do
    Gameweek.where("fpl_id > 3").destroy_all

    UpcomingForecast.call(gameweek: @weeks.first)

    assert_equal [ 1, 2, 3 ], Horizon.new("upcoming").gameweeks.pluck(:fpl_id)
    assert_not_nil Forecast.find_by(player: @player, horizon: "upcoming")
  end
end
