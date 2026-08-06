require "test_helper"

class PlayerHistoryTest < ActiveSupport::TestCase
  setup do
    @team = Team.create!(fpl_id: 930, name: "History City", short_name: "HSC", code: 930)
    @weeks = (1..3).map do |number|
      Gameweek.create!(fpl_id: 90 + number, name: "Gameweek #{90 + number}",
                       start_time: (4 - number).weeks.ago, is_finished: number < 3)
    end
    @player = Player.create!(first_name: "Past", last_name: "Player", short_name: "P.Player",
                             fpl_id: 9800, code: 9800, team: @team, position: "forward")
  end

  def history(horizon: "gameweek")
    PlayerHistory.call(player: @player, horizon: horizon)
  end

  def forecast(week, rank, horizon: "gameweek")
    Forecast.create!(player: @player, gameweek: week, horizon: horizon, rank: rank, score: 5.0)
  end

  def performance(week, score)
    Performance.create!(player: @player, gameweek: week, team: @team, gameweek_score: score)
  end

  test "one week of forecasts is a rank, not a movement" do
    forecast(@weeks[0], 10)

    assert_equal 1, history.ranks.size
    assert_nil history.rank_change
  end

  test "a rank improving by getting smaller is reported as a climb" do
    forecast(@weeks[0], 20)
    forecast(@weeks[1], 8)

    assert_equal 12, history.rank_change, "twenty to eight is up twelve, not minus twelve"
  end

  test "a rank getting worse is reported as a fall" do
    forecast(@weeks[0], 8)
    forecast(@weeks[1], 20)

    assert_equal(-12, history.rank_change)
  end

  test "the horizon on show is the one whose movement is read" do
    forecast(@weeks[0], 20)
    forecast(@weeks[1], 8)
    forecast(@weeks[0], 3, horizon: "season")
    forecast(@weeks[1], 4, horizon: "season")

    assert_equal 12, history.rank_change
    assert_equal(-1, history(horizon: "season").rank_change)
  end

  test "a season with no football played claims nothing about it" do
    refute history.played?
    assert_equal 0, history.total_points
    assert_nil history.best_week
    assert_nil history.points_per_million
  end

  test "what he has actually done is totalled, and the blanks counted" do
    performance(@weeks[0], 12)
    performance(@weeks[1], 2)
    performance(@weeks[2], 6)

    assert history.played?
    assert_equal 20, history.total_points
    assert_equal 12, history.best_week.value
    assert_equal 91, history.best_week.gameweek
    assert_equal 1, history.blanks, "two points is the bare appearance, so it did nothing for anybody"
  end

  test "points per million needs a price to divide by" do
    performance(@weeks[0], 20)

    assert_nil history.points_per_million

    Statistic.create!(player: @player, gameweek: @weeks[0], type: "now_cost", value: 100)

    assert_in_delta 2.0, history.points_per_million, 0.001
  end

  test "a rate that never moves is not a trend" do
    @weeks.each { |week| Statistic.create!(player: @player, gameweek: week, type: "expected_goals_per_90", value: 0.5) }

    assert_empty history.trends, "a flat line says nothing a single figure does not"
  end

  test "a rate that moves is shown, week by week, for the position he plays" do
    [ 0.2, 0.5, 0.9 ].each_with_index do |value, index|
      Statistic.create!(player: @player, gameweek: @weeks[index], type: "expected_goals_per_90", value: value)
    end

    trend = history.trends.find { |candidate| candidate.label == "Expected goals per 90" }

    assert_not_nil trend
    assert_equal [ 0.2, 0.5, 0.9 ], trend.points.map(&:value)
    assert_in_delta 0.9, trend.latest, 0.001
  end

  test "a goalkeeper is shown his saves and a forward is not" do
    keeper = Player.create!(first_name: "Keeps", last_name: "Player", short_name: "K.Player",
                            fpl_id: 9801, code: 9801, team: @team, position: "goalkeeper")
    [ 2.0, 4.0 ].each_with_index do |value, index|
      Statistic.create!(player: keeper, gameweek: @weeks[index], type: "saves_per_90", value: value)
    end

    labels = PlayerHistory.call(player: keeper, horizon: "gameweek").trends.map(&:label)

    assert_includes labels, "Saves per 90"
    assert_not_includes PlayerHistory::TRENDS.fetch("forward").values, "Saves per 90"
  end

  test "a price that moves is worth watching too" do
    [ 100, 101, 99 ].each_with_index do |value, index|
      Statistic.create!(player: @player, gameweek: @weeks[index], type: "now_cost", value: value)
    end

    assert history.price_history.moving?
    assert_equal [ 100.0, 101.0, 99.0 ], history.price_history.points.map(&:value)
  end
end
