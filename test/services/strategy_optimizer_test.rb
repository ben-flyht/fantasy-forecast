require "test_helper"

class StrategyOptimizerTest < ActiveSupport::TestCase
  def setup
    Forecast.delete_all
    Statistic.delete_all
    Performance.delete_all
    Match.delete_all
    Player.delete_all
    Gameweek.delete_all
    Strategy.delete_all

    @team_a = Team.find_or_create_by!(fpl_id: 600) { |t| t.name = "Opt Team A"; t.short_name = "OTA" }
    @team_b = Team.find_or_create_by!(fpl_id: 601) { |t| t.name = "Opt Team B"; t.short_name = "OTB" }

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
        fpl_id: 6000 + i,
        first_name: "Opt",
        last_name: "Player#{i}",
        position: "forward",
        team: @team_a
      )
    end

    @gameweeks.each do |gw|
      Match.create!(fpl_id: 6000 + gw.fpl_id, home_team: @team_a, away_team: @team_b, gameweek: gw)

      @players.each_with_index do |player, idx|
        Statistic.create!(player: player, gameweek: gw, type: "total_points", value: 10 - idx)
        Statistic.create!(player: player, gameweek: gw, type: "minutes", value: 90)
        Performance.create!(player: player, gameweek: gw, gameweek_score: 10 - idx, team: @team_a)
      end
    end

    @strategy = Strategy.create!(
      position: "forward",
      active: true,
      strategy_config: {
        performance: [ { metric: "total_points", weight: 1.0, lookback: 6, recency: "none" } ]
      }
    )
  end

  test "returns optimization result with expected keys" do
    result = StrategyOptimizer.call(strategy: @strategy, candidates_per_generation: 2, generations: 1)

    assert result.key?(:position)
    assert result.key?(:baseline_capture_rate)
    assert result.key?(:best_capture_rate)
    assert result.key?(:improvement)
    assert result.key?(:baseline_config)
    assert result.key?(:best_config)
    assert result.key?(:gameweeks_evaluated)
  end

  test "baseline capture rate is populated" do
    result = StrategyOptimizer.call(strategy: @strategy, candidates_per_generation: 2, generations: 1)

    assert result[:baseline_capture_rate] > 0
    assert result[:gameweeks_evaluated] > 0
  end

  test "raises error for non-position-specific strategy" do
    generic_strategy = Strategy.create!(active: true, strategy_config: { performance: [] })

    assert_raises(ArgumentError) do
      StrategyOptimizer.call(strategy: generic_strategy)
    end
  end

  test "skips optimization during cooldown period" do
    @strategy.update!(last_optimized_at: 1.day.ago)

    result = StrategyOptimizer.call(strategy: @strategy)

    assert result[:skipped]
    assert_equal 0.0, result[:improvement]
    assert_equal 0, result[:gameweeks_evaluated]
  end

  test "runs optimization after cooldown expires" do
    @strategy.update!(last_optimized_at: 5.weeks.ago)

    result = StrategyOptimizer.call(strategy: @strategy, candidates_per_generation: 2, generations: 1)

    refute result[:skipped]
    assert result[:baseline_capture_rate] > 0
  end

  test "improvement is zero or positive" do
    result = StrategyOptimizer.call(strategy: @strategy, candidates_per_generation: 2, generations: 1)

    assert result[:improvement] >= 0
  end

  test "best config is returned even when no improvement found" do
    result = StrategyOptimizer.call(strategy: @strategy, candidates_per_generation: 2, generations: 1)

    assert result[:best_config].present?
  end
end
