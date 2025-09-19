require "test_helper"

class PredictionAggregatorTest < ActiveSupport::TestCase
  def setup
    # Clear predictions to avoid fixture conflicts
    Prediction.destroy_all
    @user = users(:one)  # Prophet user
    @user2 = users(:two)  # Admin user
    @player = players(:one)
    @player2 = players(:two)
  end

  test "for_week should return aggregated prediction counts" do
    # Create predictions for week 1
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "better_than_expected", week: 1)

    # Create prediction for week 2 (should not be included)
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 2)

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
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)

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
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "better_than_expected")

    # Create predictions for @player2 (should not be included)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "worse_than_expected", week: 1)

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
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user, player: @player2, season_type: "rest_of_season", category: "better_than_expected")

    # Create predictions for @user2 (should not be included)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "worse_than_expected", week: 1)

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
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user2, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user, player: @player2, season_type: "weekly", category: "better_than_expected", week: 1)

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
end
