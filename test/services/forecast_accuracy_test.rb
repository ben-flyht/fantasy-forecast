require "test_helper"

class ForecastAccuracyTest < ActiveSupport::TestCase
  setup do
    Forecast.destroy_all
    Performance.destroy_all
    @team = Team.create!(fpl_id: 900, name: "Test United", short_name: "TST", code: 900)
    @gameweek = Gameweek.create!(fpl_id: 90, name: "Gameweek 90", start_time: 1.week.ago, is_finished: true)
  end

  # Builds a field of forwards where our forecast order can be set explicitly.
  # `scored` maps our rank position to the points that player actually returned.
  def field(scored)
    scored.each_with_index.map do |points, index|
      player = Player.create!(first_name: "P", last_name: "layer#{index}", short_name: "P#{index}",
                              fpl_id: 9000 + index, code: 9000 + index, team: @team, position: "forward")
      Forecast.create!(player: player, gameweek: @gameweek, rank: index + 1, score: (scored.size - index).to_f)
      Performance.create!(player: player, gameweek: @gameweek, team: @team, gameweek_score: points)
      player
    end
  end

  test "a perfect forecast captures everything available" do
    field((1..20).to_a.reverse) # our order is exactly the scoring order

    result = ForecastAccuracy.call(gameweek: @gameweek)

    assert_equal 100.0, result["forward"][:capture_rate]
    assert_equal 1.0, result["forward"][:correlation]
  end

  test "the week is marked against the week's forecast, not the season's" do
    players = field((1..20).to_a.reverse) # our weekly order is exactly the scoring order
    # The same week also carries a rest-of-season forecast: season-sized numbers,
    # and deliberately the opposite order.
    players.each_with_index do |player, index|
      Forecast.create!(player: player, gameweek: @gameweek, rank: index + 1,
                       score: (index + 1) * 10.0, horizon: "rest_of_season")
    end

    result = ForecastAccuracy.call(gameweek: @gameweek)

    assert_equal 100.0, result["forward"][:capture_rate], "the week's own forecast is what gets marked"
    assert_in_delta 10.5, result["forward"][:predicted], 0.1, "in the week's own numbers, not a season total"
  end

  test "a backwards forecast captures the least it could" do
    field((1..20).to_a) # our best pick scored least

    result = ForecastAccuracy.call(gameweek: @gameweek)

    assert result[:forward].nil? || result["forward"][:capture_rate] < 40.0
    assert_equal(-1.0, result["forward"][:correlation])
  end

  test "capture rate is measured against the best that could have been picked" do
    # Top 10 of ours return 10 points each; the best 10 available return 20 each.
    field([ 10 ] * 10 + [ 20 ] * 10)

    result = ForecastAccuracy.call(gameweek: @gameweek)

    assert_equal 50.0, result["forward"][:capture_rate], "half the points that were there to be had"
  end

  test "a player who did not play counts as nought, not as missing" do
    players = field([ 5 ] * 20)
    Performance.where(player: players.first).destroy_all

    result = ForecastAccuracy.call(gameweek: @gameweek)

    assert result["forward"][:capture_rate] < 100.0, "our top pick blanked and that has to count"
  end

  test "reports what the free alternatives would have got" do
    players = field((1..20).to_a.reverse)
    # FPL's own expectation is exactly wrong, the crowd is exactly right
    players.each_with_index do |player, index|
      Statistic.create!(player: player, gameweek: @gameweek, type: "ep_next", value: index + 1)
      Statistic.create!(player: player, gameweek: @gameweek, type: "selected_by_percent", value: 20 - index)
    end

    result = ForecastAccuracy.call(gameweek: @gameweek)
    baselines = result["forward"][:baselines]

    assert baselines[:crowd] > baselines[:fpl], "the crowd had them the right way round and FPL did not"
    assert baselines[:average] < 100.0, "picking blind cannot capture everything"
  end

  test "an unfinished gameweek is not marked" do
    @gameweek.update!(is_finished: false)
    field((1..20).to_a)

    assert_not ForecastAccuracy.call(gameweek: @gameweek)
  end

  test "a position with too few players to choose between is skipped" do
    field([ 5 ] * 4)

    result = ForecastAccuracy.call(gameweek: @gameweek)

    assert_nil result["forward"]
  end
end
