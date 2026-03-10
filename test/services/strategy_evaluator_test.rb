require "test_helper"

class StrategyEvaluatorTest < ActiveSupport::TestCase
  def setup
    Forecast.delete_all
    Statistic.delete_all
    Performance.delete_all
    Match.delete_all
    Player.delete_all
    Gameweek.delete_all

    @team_a = Team.find_or_create_by!(fpl_id: 500) { |t| t.name = "Team A"; t.short_name = "TMA" }
    @team_b = Team.find_or_create_by!(fpl_id: 501) { |t| t.name = "Team B"; t.short_name = "TMB" }

    @gameweeks = (1..25).map do |i|
      Gameweek.create!(
        fpl_id: i,
        name: "Gameweek #{i}",
        start_time: (30 - i).weeks.ago,
        is_finished: true
      )
    end

    @players = 5.times.map do |i|
      Player.create!(
        fpl_id: 5000 + i,
        first_name: "Eval",
        last_name: "Player#{i}",
        position: "forward",
        team: @team_a
      )
    end

    @gameweeks.each do |gw|
      Match.create!(fpl_id: 5000 + gw.fpl_id, home_team: @team_a, away_team: @team_b, gameweek: gw)

      @players.each_with_index do |player, idx|
        Statistic.create!(player: player, gameweek: gw, type: "total_points", value: 10 - idx)
        Statistic.create!(player: player, gameweek: gw, type: "minutes", value: 90)
        Performance.create!(player: player, gameweek: gw, gameweek_score: 10 - idx, team: @team_a)
      end
    end

    @strategy_config = {
      performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ]
    }
  end

  test "returns capture rate and point totals" do
    result = StrategyEvaluator.call(strategy_config: @strategy_config, position: "forward")

    assert result[:capture_rate].is_a?(Float)
    assert result[:capture_rate] > 0
    assert result[:total_predicted] > 0
    assert result[:total_optimal] > 0
    assert result[:gameweeks_evaluated] > 0
  end

  test "perfect strategy achieves 100% capture rate" do
    result = StrategyEvaluator.call(strategy_config: @strategy_config, position: "forward")

    assert_equal 100.0, result[:capture_rate],
      "Consistent player rankings should yield 100% capture when top players always score highest"
  end

  test "returns per-gameweek breakdown" do
    result = StrategyEvaluator.call(strategy_config: @strategy_config, position: "forward")

    assert result[:per_gameweek].is_a?(Array)
    assert result[:per_gameweek].size == result[:gameweeks_evaluated]

    result[:per_gameweek].each do |gw_result|
      assert gw_result.key?(:capture)
      assert gw_result.key?(:predicted_points)
      assert gw_result.key?(:optimal_points)
    end
  end

  test "returns empty result when not enough gameweeks" do
    result = StrategyEvaluator.call(
      strategy_config: @strategy_config,
      position: "forward",
      gameweek_range: @gameweeks.first(5)
    )

    assert_equal 0.0, result[:capture_rate]
    assert_equal 0, result[:gameweeks_evaluated]
  end

  test "respects custom gameweek range" do
    range = @gameweeks[10..21]
    result = StrategyEvaluator.call(
      strategy_config: @strategy_config,
      position: "forward",
      gameweek_range: range
    )

    assert_equal 12, result[:gameweeks_evaluated]
  end

  test "returns empty result for position with no players" do
    result = StrategyEvaluator.call(strategy_config: @strategy_config, position: "goalkeeper")

    assert_equal 0.0, result[:capture_rate]
    assert_equal 0, result[:gameweeks_evaluated]
  end

  test "accepts string keys in strategy config" do
    config = {
      "performance" => [ { "metric" => "total_points", "weight" => 1.0, "lookback" => 3, "recency" => "none" } ]
    }

    result = StrategyEvaluator.call(strategy_config: config, position: "forward")

    assert result[:capture_rate] > 0
  end
end
