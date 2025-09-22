require "test_helper"

class ForecastAggregatorTest < ActiveSupport::TestCase
  def setup
    # Clear data to avoid fixture conflicts
    Forecast.destroy_all
    Gameweek.destroy_all

    @user = users(:one)  # Forecaster user
    @user2 = users(:two)  # Admin user
    @player = players(:one)
    @player2 = players(:two)

    # Create gameweeks for testing
    @gameweek1 = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: 1.week.ago,
      end_time: Time.current - 1.second,
      is_current: true,
      is_next: false,
      is_finished: false
    )

    @gameweek2 = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current,
      end_time: 1.week.from_now - 1.second,
      is_current: false,
      is_next: true,
      is_finished: false
    )
  end

  test "for_week should return aggregated forecast counts" do
    # Create forecasts for gameweek 1
    Forecast.create!(user: @user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user2, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user, player: @player2, category: "avoid", gameweek: @gameweek1)

    # Create forecast for gameweek 2 (should not be included)
    Forecast.create!(user: @user2, player: @player2, category: "target", gameweek: @gameweek2)

    result = ForecastAggregator.for_week(1)

    # Should have results for both players
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check player1 counts (2 targets)
    assert_equal 2, result[@player.id]["target"]
    assert_equal 0, result[@player.id]["avoid"]

    # Check player2 counts (1 avoid for gameweek1)
    assert_equal 0, result[@player2.id]["target"]
    assert_equal 1, result[@player2.id]["avoid"]
  end

  test "for_player should return aggregated forecasts for specific player" do
    Forecast.create!(user: @user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user2, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user, player: @player, category: "avoid", gameweek: @gameweek2)
    Forecast.create!(user: @user, player: @player2, category: "target", gameweek: @gameweek1)

    result = ForecastAggregator.for_player(@player.id)

    # Should only have data for the specified player
    assert_equal 1, result.keys.length
    assert result.key?(@player.id)
    assert_not result.key?(@player2.id)

    # Should aggregate across all gameweeks
    assert_equal 2, result[@player.id]["target"]
    assert_equal 1, result[@player.id]["avoid"]
  end

  test "for_user should return aggregated forecasts for specific user" do
    Forecast.create!(user: @user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user, player: @player2, category: "avoid", gameweek: @gameweek1)
    Forecast.create!(user: @user2, player: @player, category: "target", gameweek: @gameweek1)

    result = ForecastAggregator.for_user(@user.id)

    # Should have data for both players that user predicted
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check counts
    assert_equal 1, result[@player.id]["target"]
    assert_equal 1, result[@player2.id]["avoid"]
  end

  test "consensus_summary_for_week should return formatted consensus data" do
    # Create multiple forecasts for week 1
    Forecast.create!(user: @user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user2, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user, player: @player2, category: "avoid", gameweek: @gameweek1)

    result = ForecastAggregator.consensus_summary_for_week(1)

    # Check structure
    assert result.is_a?(Hash)
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check player1 has 2 target votes
    assert_equal 2, result[@player.id]["target"]

    # Check player2 has 1 avoid vote
    assert_equal 1, result[@player2.id]["avoid"]
  end

  test "should handle empty results gracefully" do
    # No forecasts created
    result = ForecastAggregator.for_week(1)
    assert result.is_a?(Hash)
    assert result.empty?
  end

  test "weekly_consensus should return data with Player objects" do
    Forecast.create!(user: @user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user2, player: @player, category: "target", gameweek: @gameweek1)

    result = ForecastAggregator.weekly_consensus(1)

    assert result.is_a?(Hash)
    assert result.key?(@player.id)

    # Check structure includes player object
    assert_equal @player, result[@player.id][:player]
    assert_equal({ "target" => 2 }, result[@player.id][:votes])
    assert_equal 2, result[@player.id][:total_votes]
  end

  test "top_for_week should return top N players for specific category" do
    # Create forecasts with different vote counts
    3.times do
      user = User.create!(email: "test#{rand(1000)}@example.com", username: "test#{rand(1000)}", password: "password")
      Forecast.create!(user: user, player: @player, category: "target", gameweek: @gameweek1)
    end
    Forecast.create!(user: @user, player: @player2, category: "target", gameweek: @gameweek1)

    result = ForecastAggregator.top_for_week(1, "target", 2)

    # Should return top 2 players
    assert_equal 2, result.length

    # First should be @player with 3 votes
    assert_equal @player, result[0][:player]
    assert_equal 3, result[0][:votes]

    # Second should be @player2 with 1 vote
    assert_equal @player2, result[1][:player]
    assert_equal 1, result[1][:votes]
  end

  test "top_for_week should respect limit parameter" do
    # Create a team first
    team = Team.create!(name: "Test Team", short_name: "TST", fpl_id: 99)

    # Create forecasts for multiple players
    5.times do |i|
      player = Player.create!(first_name: "Player", last_name: "#{i}", team: team, position: "forward", fpl_id: 500 + i)
      Forecast.create!(user: @user, player: player, category: "target", gameweek: @gameweek1)
    end

    result = ForecastAggregator.top_for_week(1, "target", 3)

    # Should only return 3 players despite having 5
    assert_equal 3, result.length
  end

  test "weekly_consensus_by_category should organize data by category" do
    Forecast.create!(user: @user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user2, player: @player2, category: "avoid", gameweek: @gameweek1)

    result = ForecastAggregator.weekly_consensus_by_category(1)

    # Check structure
    assert result.is_a?(Hash)
    assert result.key?("target")
    assert result.key?("avoid")

    # Check target category has player1
    assert_equal 1, result["target"].length
    assert_equal @player, result["target"][0][:player]

    # Check avoid category has player2
    assert_equal 1, result["avoid"].length
    assert_equal @player2, result["avoid"][0][:player]
  end

  test "should filter out players with zero votes in specific category" do
    Forecast.create!(user: @user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @user, player: @player2, category: "avoid", gameweek: @gameweek1)

    result = ForecastAggregator.top_for_week(1, "target", 10)

    # Should only include player1 who has target votes
    assert_equal 1, result.length
    assert_equal @player, result[0][:player]
  end
end
