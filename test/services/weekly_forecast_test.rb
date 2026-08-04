require "test_helper"

class WeeklyForecastTest < ActiveSupport::TestCase
  setup do
    Forecast.destroy_all
    Strategy.destroy_all
    @team = Team.create!(fpl_id: 800, name: "Test City", short_name: "TCY", code: 800)
    @opponent = Team.create!(fpl_id: 801, name: "Test Rovers", short_name: "TRV", code: 801)
    @gameweek = Gameweek.create!(fpl_id: 80, name: "Gameweek 80", start_time: 2.days.from_now, is_next: true)
    Match.create!(gameweek: @gameweek, home_team: @team, away_team: @opponent,
                  fpl_id: 8000, home_difficulty: 2, away_difficulty: 4)
    @player = player_with_record
  end

  def player_with_record(fpl_id: 8100)
    player = Player.create!(first_name: "Test", last_name: "Player#{fpl_id}", short_name: "T#{fpl_id}",
                            fpl_id: fpl_id, code: fpl_id, team: @team, position: "forward")
    {
      "last_season_minutes" => 3000.0, "season_minutes" => 3000.0,
      "last_season_expected_goals_per_90" => 0.5, "expected_goals_per_90" => 0.5,
      "last_season_expected_goal_involvements_per_90" => 0.7,
      "expected_goal_involvements_per_90" => 0.7, "selected_by_percent" => 10.0, "now_cost" => 80.0
    }.each { |type, value| Statistic.create!(player: player, gameweek: @gameweek, type: type, value: value) }
    player
  end

  # Minitest's mock is not available here, so swap the method itself.
  def with_parameters(tuned)
    original = ExpectedPoints.method(:parameters)
    ExpectedPoints.define_singleton_method(:parameters) { tuned }
    yield
  ensure
    ExpectedPoints.define_singleton_method(:parameters, original)
  end

  test "writes a forecast with its working for a position it can score" do
    WeeklyForecast.call(gameweek: @gameweek)

    forecast = Forecast.find_by(player: @player, gameweek: @gameweek)
    assert forecast.score.to_f.positive?
    assert_equal 1, forecast.rank
    assert_equal 90, forecast.working["minutes"]
    assert_equal [ { "name" => "Test Rovers", "home" => true, "difficulty" => 2 } ], forecast.working["opponents"]
  end

  test "records the settings the forecast was actually made with" do
    WeeklyForecast.call(gameweek: @gameweek)
    config = Forecast.first.strategy.strategy_config

    assert_equal ExpectedPoints.parameters, config.except(:model)
    assert_equal Forecaster::MODEL, config[:model], "how the evidence was read is a setting too"
  end

  test "a changed setting is recorded as a new set, leaving earlier forecasts pointing at the old one" do
    WeeklyForecast.call(gameweek: @gameweek)
    was = Forecast.first.strategy

    tuned = ExpectedPoints.parameters.merge(clamp_width: 0.5)
    with_parameters(tuned) { WeeklyForecast.call(gameweek: @gameweek) }

    assert_equal 2, Strategy.count, "the old settings are kept, not overwritten"
    assert_equal tuned, Forecast.first.strategy.strategy_config.except(:model)
    assert_equal ExpectedPoints.parameters, was.reload.strategy_config.except(:model),
                 "what produced last week's forecast must not change under it"
  end

  test "reads only the record that stood by this gameweek" do
    WeeklyForecast.call(gameweek: @gameweek)
    was = Forecast.find_by(player: @player, gameweek: @gameweek).score

    later = Gameweek.create!(fpl_id: 81, name: "Gameweek 81", start_time: 9.days.from_now)
    Statistic.create!(player: @player, gameweek: later, type: "expected_goals_per_90", value: 5.0)
    WeeklyForecast.call(gameweek: @gameweek)

    assert_equal was, Forecast.find_by(player: @player, gameweek: @gameweek).score,
                 "a week cannot be re-forecast with form it could not have known"
  end

  test "a fitness doubt from a week gone by does not follow a player into this one" do
    WeeklyForecast.call(gameweek: @gameweek)
    fit = Forecast.find_by(player: @player, gameweek: @gameweek).score

    Statistic.create!(player: @player, gameweek: gameweeks(:finished), type: "chance_of_playing", value: 25)
    WeeklyForecast.call(gameweek: @gameweek)

    assert_equal fit, Forecast.find_by(player: @player, gameweek: @gameweek).score,
                 "he recovered: FPL says nothing about him this week, and nor should we"
  end

  test "a fitness doubt about this week counts against him" do
    WeeklyForecast.call(gameweek: @gameweek)
    fit = Forecast.find_by(player: @player, gameweek: @gameweek).score

    Statistic.create!(player: @player, gameweek: @gameweek, type: "chance_of_playing", value: 25)
    WeeklyForecast.call(gameweek: @gameweek)

    assert_operator Forecast.find_by(player: @player, gameweek: @gameweek).score, :<, fit
  end

  test "refuses to write a position it cannot score anybody in" do
    Match.destroy_all # nobody has a fixture, so everybody multiplies to nought

    assert_not WeeklyForecast.call(gameweek: @gameweek)
    assert_equal 0, Forecast.count, "a wall of noughts is worse than no answer at all"
  end

  test "refusing leaves the forecast that was already there" do
    WeeklyForecast.call(gameweek: @gameweek)
    was = Forecast.find_by(player: @player, gameweek: @gameweek).score

    Match.destroy_all
    WeeklyForecast.call(gameweek: @gameweek)

    assert_equal was, Forecast.find_by(player: @player, gameweek: @gameweek).score,
                 "last week's honest number beats this week's nought"
  end

  test "says which input was missing when it refuses" do
    Match.destroy_all
    log = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    begin
      WeeklyForecast.call(gameweek: @gameweek)
    ensure
      Rails.logger = original
    end

    assert_match(/Refusing to write forward forecasts/, log.string)
    assert_match(/with a fixture/, log.string, "it must name the input that was absent")
  end

  test "a gameweek that has already been played is never rewritten" do
    @gameweek.update!(is_finished: true)

    assert_not WeeklyForecast.call(gameweek: @gameweek)
    assert_equal 0, Forecast.count, "once the football has happened the forecast is evidence"
  end

  test "a player with no record still gets a row, so the position is complete" do
    unknown = Player.create!(first_name: "No", last_name: "Record", short_name: "NR",
                             fpl_id: 8200, code: 8200, team: @team, position: "forward")

    WeeklyForecast.call(gameweek: @gameweek)
    forecast = Forecast.find_by(player: unknown, gameweek: @gameweek)

    assert_nil forecast.score, "unknown is not the same as nought"
    assert forecast.rank > Forecast.find_by(player: @player).rank, "and he sits below the players we can read"
  end
end
