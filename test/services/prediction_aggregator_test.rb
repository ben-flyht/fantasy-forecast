require "test_helper"

class PredictionAggregatorTest < ActiveSupport::TestCase
  def setup
    # Clear data to avoid fixture conflicts
    Prediction.destroy_all
    Gameweek.destroy_all

    @user = users(:one)  # Prophet user
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

  test "for_week should return aggregated prediction counts" do
    # Create predictions for gameweek 1
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "better_than_expected", gameweek: @gameweek1)

    # Create prediction for gameweek 2 (should not be included)
    Prediction.create!(user: @user2, player: @player2, season_type: "weekly", category: "must_have", gameweek: @gameweek2)

    result = PredictionAggregator.for_week(1)

    # Should have results for both players
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check @player predictions
    player_data = result[@player.id]
    assert_equal 2, player_data["must_have"]
    assert_equal 0, player_data["better_than_expected"]
    assert_equal 0, player_data["worse_than_expected"]

    # Check @player2 predictions
    player2_data = result[@player2.id]
    assert_equal 0, player2_data["must_have"]
    assert_equal 1, player2_data["better_than_expected"]
    assert_equal 0, player2_data["worse_than_expected"]
  end

  test "for_rest_of_season should return aggregated season prediction counts" do
    # Create rest of season predictions
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @user2, player: @player, season_type: "rest_of_season", category: "better_than_expected")
    Prediction.create!(user: @user, player: @player2, season_type: "rest_of_season", category: "worse_than_expected")

    # Create weekly prediction (should not be included)
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)

    result = PredictionAggregator.for_rest_of_season

    # Should have results for both players
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check @player predictions
    player_data = result[@player.id]
    assert_equal 1, player_data["must_have"]
    assert_equal 1, player_data["better_than_expected"]
    assert_equal 0, player_data["worse_than_expected"]

    # Check @player2 predictions
    player2_data = result[@player2.id]
    assert_equal 0, player2_data["must_have"]
    assert_equal 0, player2_data["better_than_expected"]
    assert_equal 1, player2_data["worse_than_expected"]
  end

  test "for_player should return aggregated predictions for specific player" do
    # Create predictions for @player
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "better_than_expected")

    # Create predictions for @player2 (should not be included)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "worse_than_expected", gameweek: @gameweek1)

    result = PredictionAggregator.for_player(@player.id)

    # Should have results only for @player
    assert_equal 1, result.keys.length
    assert result.key?(@player.id)
    assert_not result.key?(@player2.id)

    # Check @player predictions
    player_data = result[@player.id]
    assert_equal 2, player_data["must_have"]
    assert_equal 1, player_data["better_than_expected"]
    assert_equal 0, player_data["worse_than_expected"]
  end

  test "for_user should return aggregated predictions for specific user" do
    # Create predictions for @user
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: @player2, season_type: "rest_of_season", category: "better_than_expected")

    # Create predictions for @user2 (should not be included)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "worse_than_expected", gameweek: @gameweek1)

    result = PredictionAggregator.for_user(@user.id)

    # Should have results for both players predicted by @user
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check @player predictions
    player_data = result[@player.id]
    assert_equal 1, player_data["must_have"]
    assert_equal 0, player_data["better_than_expected"]
    assert_equal 0, player_data["worse_than_expected"]

    # Check @player2 predictions
    player2_data = result[@player2.id]
    assert_equal 0, player2_data["must_have"]
    assert_equal 1, player2_data["better_than_expected"]
    assert_equal 0, player2_data["worse_than_expected"]
  end

  test "consensus_summary_for_week should return formatted consensus data" do
    # Create predictions for week 1
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "better_than_expected", gameweek: @gameweek1)

    result = PredictionAggregator.consensus_summary_for_week(1)

    # Should have results for both players
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check @player consensus
    assert_equal 2, result[@player.id]["must_have"]

    # Check @player2 consensus
    assert_equal 1, result[@player2.id]["better_than_expected"]
  end

  test "consensus_summary_rest_of_season should return formatted season consensus data" do
    # Create rest of season predictions
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @user2, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @user, player: @player2, season_type: "rest_of_season", category: "worse_than_expected")

    result = PredictionAggregator.consensus_summary_rest_of_season

    # Should have results for both players
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check @player consensus
    assert_equal 2, result[@player.id]["must_have"]

    # Check @player2 consensus
    assert_equal 1, result[@player2.id]["worse_than_expected"]
  end

  test "should handle empty results gracefully" do
    # No predictions created

    result_week = PredictionAggregator.for_week(1)
    assert_equal({}, result_week)

    result_season = PredictionAggregator.for_rest_of_season
    assert_equal({}, result_season)

    result_player = PredictionAggregator.for_player(@player.id)
    assert_equal({}, result_player)

    result_user = PredictionAggregator.for_user(@user.id)
    assert_equal({}, result_user)

    result_consensus_week = PredictionAggregator.consensus_summary_for_week(1)
    assert_equal({}, result_consensus_week)

    result_consensus_season = PredictionAggregator.consensus_summary_rest_of_season
    assert_equal({}, result_consensus_season)
  end

  # Tests for enhanced consensus methods
  test "weekly_consensus should return data with Player objects" do
    # Create predictions for week 1
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "better_than_expected", gameweek: @gameweek1)

    result = PredictionAggregator.weekly_consensus(1)

    # Should have results for both players
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check structure includes player object
    player_data = result[@player.id]
    assert_equal @player, player_data[:player]
    assert_equal 2, player_data[:votes]["must_have"]
    assert_equal 2, player_data[:total_votes]

    player2_data = result[@player2.id]
    assert_equal @player2, player2_data[:player]
    assert_equal 1, player2_data[:votes]["better_than_expected"]
    assert_equal 1, player2_data[:total_votes]
  end

  test "rest_of_season_consensus should return data with Player objects" do
    # Create rest of season predictions
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @user2, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @user, player: @player2, season_type: "rest_of_season", category: "worse_than_expected")

    result = PredictionAggregator.rest_of_season_consensus

    # Should have results for both players
    assert_equal 2, result.keys.length
    assert result.key?(@player.id)
    assert result.key?(@player2.id)

    # Check structure includes player object
    player_data = result[@player.id]
    assert_equal @player, player_data[:player]
    assert_equal 2, player_data[:votes]["must_have"]
    assert_equal 2, player_data[:total_votes]

    player2_data = result[@player2.id]
    assert_equal @player2, player2_data[:player]
    assert_equal 1, player2_data[:votes]["worse_than_expected"]
    assert_equal 1, player2_data[:total_votes]
  end

  test "top_for_week should return top N players for specific category" do
    # Create predictions with different vote counts
    # @player gets 3 votes for must_have
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)

    # @player2 gets 1 vote for must_have
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "must_have", gameweek: @gameweek1)

    result = PredictionAggregator.top_for_week(1, "must_have", 10)

    # Should return players sorted by vote count
    assert_equal 2, result.length

    # First player should be @player with 2 votes
    assert_equal @player, result.first[:player]
    assert_equal 2, result.first[:votes]

    # Second player should be @player2 with 1 vote
    assert_equal @player2, result.second[:player]
    assert_equal 1, result.second[:votes]
  end

  test "top_for_week should respect limit parameter" do
    # Create 3 different players with predictions
    player3 = Player.create!(name: "Player 3", team: "Team 3", position: "FWD", fpl_id: 3003)

    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: player3, season_type: "weekly", category: "must_have", gameweek: @gameweek1)

    # Request only top 2
    result = PredictionAggregator.top_for_week(1, "must_have", 2)
    assert_equal 2, result.length
  end

  test "top_rest_of_season should return top N players for specific category" do
    # Create rest of season predictions
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "better_than_expected")
    Prediction.create!(user: @user2, player: @player, season_type: "rest_of_season", category: "better_than_expected")
    Prediction.create!(user: @user, player: @player2, season_type: "rest_of_season", category: "better_than_expected")

    result = PredictionAggregator.top_rest_of_season("better_than_expected", 10)

    # Should return players sorted by vote count
    assert_equal 2, result.length

    # First player should be @player with 2 votes
    assert_equal @player, result.first[:player]
    assert_equal 2, result.first[:votes]

    # Second player should be @player2 with 1 vote
    assert_equal @player2, result.second[:player]
    assert_equal 1, result.second[:votes]
  end

  test "weekly_consensus_by_category should organize data by category" do
    # Create predictions across different categories
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user2, player: @player2, season_type: "weekly", category: "better_than_expected", gameweek: @gameweek1)

    result = PredictionAggregator.weekly_consensus_by_category(1)

    # Should have all three categories
    assert result.key?("must_have")
    assert result.key?("better_than_expected")
    assert result.key?("worse_than_expected")

    # Must have category should have @player
    assert_equal 1, result["must_have"].length
    assert_equal @player, result["must_have"].first[:player]

    # Better than expected should have @player2
    assert_equal 1, result["better_than_expected"].length
    assert_equal @player2, result["better_than_expected"].first[:player]

    # Worse than expected should be empty
    assert_equal 0, result["worse_than_expected"].length
  end

  test "rest_of_season_consensus_by_category should organize data by category" do
    # Create rest of season predictions
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @user2, player: @player2, season_type: "rest_of_season", category: "worse_than_expected")

    result = PredictionAggregator.rest_of_season_consensus_by_category

    # Should have all three categories
    assert result.key?("must_have")
    assert result.key?("better_than_expected")
    assert result.key?("worse_than_expected")

    # Must have category should have @player
    assert_equal 1, result["must_have"].length
    assert_equal @player, result["must_have"].first[:player]

    # Worse than expected should have @player2
    assert_equal 1, result["worse_than_expected"].length
    assert_equal @player2, result["worse_than_expected"].first[:player]

    # Better than expected should be empty
    assert_equal 0, result["better_than_expected"].length
  end

  test "should filter out players with zero votes in specific category" do
    # Create predictions where @player has votes in must_have but not better_than_expected
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "better_than_expected", gameweek: @gameweek1)

    # Request better_than_expected - should only return @player2
    result = PredictionAggregator.top_for_week(1, "better_than_expected", 10)

    assert_equal 1, result.length
    assert_equal @player2, result.first[:player]
    assert_equal 1, result.first[:votes]
  end
end
