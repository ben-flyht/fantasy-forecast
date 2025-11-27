require "test_helper"

class StrategyRunnerTest < ActiveSupport::TestCase
  def setup
    @team = Team.find_or_create_by!(fpl_id: 201) do |t|
      t.name = "Strategy Test Team"
      t.short_name = "STT"
    end

    # Create gameweeks
    @gw1 = Gameweek.create!(fpl_id: 201, name: "Gameweek 201", start_time: 3.weeks.ago, is_finished: true)
    @gw2 = Gameweek.create!(fpl_id: 202, name: "Gameweek 202", start_time: 2.weeks.ago, is_finished: true)
    @gw3 = Gameweek.create!(fpl_id: 203, name: "Gameweek 203", start_time: 1.week.ago, is_finished: true)
    @current_gw = Gameweek.create!(fpl_id: 204, name: "Gameweek 204", start_time: 1.day.from_now, is_finished: false)

    # Create midfielders with different point histories
    @player_high = Player.create!(fpl_id: 2001, first_name: "High", last_name: "Scorer", position: :midfielder, team: @team)
    @player_mid = Player.create!(fpl_id: 2002, first_name: "Mid", last_name: "Scorer", position: :midfielder, team: @team)
    @player_low = Player.create!(fpl_id: 2003, first_name: "Low", last_name: "Scorer", position: :midfielder, team: @team)

    # Create statistics - high scorer consistently scores high
    create_statistic(@player_high, @gw1, "total_points", 10)
    create_statistic(@player_high, @gw2, "total_points", 12)
    create_statistic(@player_high, @gw3, "total_points", 15)

    # Mid scorer has moderate scores
    create_statistic(@player_mid, @gw1, "total_points", 6)
    create_statistic(@player_mid, @gw2, "total_points", 7)
    create_statistic(@player_mid, @gw3, "total_points", 8)

    # Low scorer has low scores
    create_statistic(@player_low, @gw1, "total_points", 2)
    create_statistic(@player_low, @gw2, "total_points", 3)
    create_statistic(@player_low, @gw3, "total_points", 4)
  end

  test "selects players based on total_points with no recency weighting" do
    config = {
      strategies: [
        { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" }
      ]
    }

    result = StrategyRunner.call(config, position: "midfielder", count: 2, gameweek: @current_gw)

    assert_equal 2, result.size
    assert_includes result, @player_high
    assert_includes result, @player_mid
    assert_not_includes result, @player_low
  end

  test "selects random players when config is empty" do
    result = StrategyRunner.call({}, position: "midfielder", count: 2, gameweek: @current_gw)

    assert_equal 2, result.size
    result.each { |player| assert_equal "midfielder", player.position }
  end

  test "raises error for invalid recency type" do
    config = {
      strategies: [
        { metric: "total_points", weight: 1.0, lookback: 3, recency: "invalid" }
      ]
    }

    assert_raises(ArgumentError) do
      StrategyRunner.call(config, position: "midfielder", count: 2, gameweek: @current_gw)
    end
  end

  test "raises error for invalid metric" do
    config = {
      strategies: [
        { metric: "invalid_metric", weight: 1.0, lookback: 3, recency: "none" }
      ]
    }

    assert_raises(ArgumentError) do
      StrategyRunner.call(config, position: "midfielder", count: 2, gameweek: @current_gw)
    end
  end

  test "linear recency weighting favors recent performance" do
    # Create a player who was bad early but good recently
    @player_improving = Player.create!(fpl_id: 2004, first_name: "Improving", last_name: "Player", position: :midfielder, team: @team)
    create_statistic(@player_improving, @gw1, "total_points", 1)
    create_statistic(@player_improving, @gw2, "total_points", 5)
    create_statistic(@player_improving, @gw3, "total_points", 25)

    # Create a player who was good early but bad recently
    @player_declining = Player.create!(fpl_id: 2005, first_name: "Declining", last_name: "Player", position: :midfielder, team: @team)
    create_statistic(@player_declining, @gw1, "total_points", 25)
    create_statistic(@player_declining, @gw2, "total_points", 5)
    create_statistic(@player_declining, @gw3, "total_points", 1)

    config = {
      strategies: [
        { metric: "total_points", weight: 1.0, lookback: 3, recency: "linear" }
      ]
    }

    result = StrategyRunner.call(config, position: "midfielder", count: 1, gameweek: @current_gw)

    # With linear weighting, improving player should rank higher than declining player
    # Improving: (1×1 + 5×2 + 25×3) / 6 = 86/6 ≈ 14.33
    # Declining: (25×1 + 5×2 + 1×3) / 6 = 38/6 ≈ 6.33
    assert_equal [@player_improving], result
  end

  test "exponential recency weighting heavily favors recent performance" do
    @player_improving = Player.create!(fpl_id: 2006, first_name: "Improving2", last_name: "Player", position: :midfielder, team: @team)
    create_statistic(@player_improving, @gw1, "total_points", 0)
    create_statistic(@player_improving, @gw2, "total_points", 0)
    create_statistic(@player_improving, @gw3, "total_points", 25)

    @player_consistent = Player.create!(fpl_id: 2007, first_name: "Consistent", last_name: "Player", position: :midfielder, team: @team)
    create_statistic(@player_consistent, @gw1, "total_points", 5)
    create_statistic(@player_consistent, @gw2, "total_points", 5)
    create_statistic(@player_consistent, @gw3, "total_points", 5)

    config = {
      strategies: [
        { metric: "total_points", weight: 1.0, lookback: 3, recency: "exponential" }
      ]
    }

    result = StrategyRunner.call(config, position: "midfielder", count: 1, gameweek: @current_gw)

    # With exponential weighting (2^0, 2^1, 2^2 = 1, 2, 4):
    # Improving: (0×1 + 0×2 + 25×4) / 7 = 100/7 ≈ 14.29
    # High scorer: (10×1 + 12×2 + 15×4) / 7 = 94/7 ≈ 13.43
    assert_equal [@player_improving], result
  end

  test "composite strategy combines multiple metrics" do
    # Add goals_scored stats
    create_statistic(@player_high, @gw3, "goals_scored", 0)
    create_statistic(@player_mid, @gw3, "goals_scored", 3)
    create_statistic(@player_low, @gw3, "goals_scored", 0)

    config = {
      strategies: [
        { metric: "total_points", weight: 0.5, lookback: 1, recency: "none" },
        { metric: "goals_scored", weight: 0.5, lookback: 1, recency: "none" }
      ]
    }

    result = StrategyRunner.call(config, position: "midfielder", count: 2, gameweek: @current_gw)

    # player_high: 15 * 0.5 + 0 * 0.5 = 7.5
    # player_mid: 8 * 0.5 + 3 * 0.5 = 5.5
    # player_low: 4 * 0.5 + 0 * 0.5 = 2.0
    assert_includes result, @player_high
    assert_includes result, @player_mid
  end

  test "availability filter excludes players with low chance of playing" do
    @player_high.update!(chance_of_playing: 0)
    @player_mid.update!(chance_of_playing: 100)
    @player_low.update!(chance_of_playing: 75)

    config = {
      strategies: [
        { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" }
      ],
      filters: {
        availability: { min_chance_of_playing: 75 }
      }
    }

    result = StrategyRunner.call(config, position: "midfielder", count: 3, gameweek: @current_gw)

    assert_not_includes result, @player_high
    assert_includes result, @player_mid
    assert_includes result, @player_low
  end

  test "availability filter allows null chance_of_playing" do
    @player_high.update!(chance_of_playing: nil)
    @player_mid.update!(chance_of_playing: 100)
    @player_low.update!(chance_of_playing: 0)

    config = {
      strategies: [
        { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" }
      ],
      filters: {
        availability: { min_chance_of_playing: 50 }
      }
    }

    result = StrategyRunner.call(config, position: "midfielder", count: 3, gameweek: @current_gw)

    assert_includes result, @player_high  # nil is allowed
    assert_includes result, @player_mid
    assert_not_includes result, @player_low
  end

  private

  def create_statistic(player, gameweek, type, value)
    Statistic.create!(player: player, gameweek: gameweek, type: type, value: value)
  end
end
