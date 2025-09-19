require "test_helper"

class PredictionTest < ActiveSupport::TestCase
  def setup
    # Clear predictions to avoid fixture conflicts
    Prediction.destroy_all
    @user = users(:one)  # Prophet user
    @player = players(:one)
  end

  test "should belong to user" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )
    assert prediction.valid?
    assert_equal @user, prediction.user
  end

  test "should belong to player" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )
    assert prediction.valid?
    assert_equal @player, prediction.player
  end

  test "should require season_type" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      category: "must_have",
      week: 1
    )
    assert_not prediction.valid?
    assert_includes prediction.errors[:season_type], "can't be blank"
  end

  test "should require category" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      week: 1
    )
    assert_not prediction.valid?
    assert_includes prediction.errors[:category], "can't be blank"
  end

  test "should require week when season_type is weekly" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have"
    )
    assert_not prediction.valid?
    assert_includes prediction.errors[:week], "can't be blank"
  end

  test "should not require week when season_type is rest_of_season" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "rest_of_season",
      category: "must_have"
    )
    assert prediction.valid?
  end

  test "should enforce uniqueness constraint" do
    # Create first prediction
    prediction1 = Prediction.create!(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )

    # Try to create duplicate prediction
    prediction2 = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "better_than_expected",  # Different category, but same user/player/week/season_type
      week: 1
    )

    assert_not prediction2.valid?
    assert_includes prediction2.errors[:user_id], "has already been taken"
  end

  test "should allow different users to predict same player/week" do
    user2 = users(:two)  # Admin user

    # Create first prediction
    prediction1 = Prediction.create!(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )

    # Different user should be able to predict same player/week
    prediction2 = Prediction.new(
      user: user2,
      player: @player,
      season_type: "weekly",
      category: "better_than_expected",
      week: 1
    )

    assert prediction2.valid?
  end

  test "should allow same user to predict same player for different weeks" do
    # Create first prediction
    prediction1 = Prediction.create!(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )

    # Same user should be able to predict same player for different week
    prediction2 = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "better_than_expected",
      week: 2
    )

    assert prediction2.valid?
  end

  test "should validate season_type enum" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      category: "must_have",
      week: 1
    )

    # Valid season types
    prediction.season_type = "weekly"
    assert prediction.weekly?

    prediction.season_type = "rest_of_season"
    assert prediction.rest_of_season?
  end

  test "should validate category enum" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      week: 1
    )

    # Valid categories
    prediction.category = "must_have"
    assert prediction.must_have?

    prediction.category = "better_than_expected"
    assert prediction.better_than_expected?

    prediction.category = "worse_than_expected"
    assert prediction.worse_than_expected?
  end

  test "scopes should work correctly" do
    # Create test predictions
    pred1 = Prediction.create!(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )

    pred2 = Prediction.create!(
      user: @user,
      player: players(:two),
      season_type: "rest_of_season",
      category: "better_than_expected"
    )

    # Test scopes
    assert_includes Prediction.by_category("must_have"), pred1
    assert_not_includes Prediction.by_category("must_have"), pred2

    assert_includes Prediction.by_week(1), pred1
    assert_not_includes Prediction.by_week(1), pred2

    assert_includes Prediction.weekly_predictions, pred1
    assert_not_includes Prediction.weekly_predictions, pred2

    assert_includes Prediction.season_predictions, pred2
    assert_not_includes Prediction.season_predictions, pred1
  end

  test "additional scopes should work correctly" do
    user2 = users(:two)  # Admin user
    player2 = players(:two)

    # Create test predictions
    pred1 = Prediction.create!(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )

    pred2 = Prediction.create!(
      user: user2,
      player: player2,
      season_type: "weekly",
      category: "better_than_expected",
      week: 2
    )

    pred3 = Prediction.create!(
      user: @user,
      player: player2,
      season_type: "rest_of_season",
      category: "worse_than_expected"
    )

    # Test for_week scope
    assert_includes Prediction.for_week(1), pred1
    assert_not_includes Prediction.for_week(1), pred2
    assert_not_includes Prediction.for_week(1), pred3

    # Test for_season_type scope
    assert_includes Prediction.for_season_type("weekly"), pred1
    assert_includes Prediction.for_season_type("weekly"), pred2
    assert_not_includes Prediction.for_season_type("weekly"), pred3

    # Test for_player scope
    assert_includes Prediction.for_player(@player.id), pred1
    assert_not_includes Prediction.for_player(@player.id), pred2
    assert_not_includes Prediction.for_player(@player.id), pred3

    # Test for_user scope
    assert_includes Prediction.for_user(@user.id), pred1
    assert_not_includes Prediction.for_user(@user.id), pred2
    assert_includes Prediction.for_user(@user.id), pred3
  end

  test "consensus_for_week should aggregate predictions correctly" do
    user2 = users(:two)  # Admin user
    player2 = players(:two)

    # Create predictions for week 1
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: user2, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @user, player: player2, season_type: "weekly", category: "better_than_expected", week: 1)

    # Create prediction for week 2 (should not be included)
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 2)

    consensus = Prediction.consensus_for_week(1)
    consensus_array = consensus.to_a

    # Should have 2 results for week 1
    assert_equal 2, consensus_array.length

    # Find the must_have prediction for @player
    must_have_result = consensus_array.find { |p| p.player_id == @player.id && p.category == "must_have" }
    assert_not_nil must_have_result
    assert_equal 2, must_have_result.count  # Two users predicted must_have for this player

    # Find the better_than_expected prediction for player2
    better_result = consensus_array.find { |p| p.player_id == player2.id && p.category == "better_than_expected" }
    assert_not_nil better_result
    assert_equal 1, better_result.count  # One user predicted better_than_expected for this player
  end

  test "consensus_rest_of_season should aggregate season predictions correctly" do
    user2 = users(:two)  # Admin user
    player2 = players(:two)

    # Create rest of season predictions
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: user2, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @user, player: player2, season_type: "rest_of_season", category: "worse_than_expected")

    # Create weekly prediction (should not be included)
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)

    consensus = Prediction.consensus_rest_of_season
    consensus_array = consensus.to_a

    # Should have 2 results for rest of season
    assert_equal 2, consensus_array.length

    # Find the must_have prediction for @player
    must_have_result = consensus_array.find { |p| p.player_id == @player.id && p.category == "must_have" }
    assert_not_nil must_have_result
    assert_equal 2, must_have_result.count  # Two users predicted must_have for this player

    # Find the worse_than_expected prediction for player2
    worse_result = consensus_array.find { |p| p.player_id == player2.id && p.category == "worse_than_expected" }
    assert_not_nil worse_result
    assert_equal 1, worse_result.count  # One user predicted worse_than_expected for this player
  end

  test "top_players_by_category_for_week should return ordered results" do
    user2 = users(:two)  # Admin user
    player2 = players(:two)

    # Create multiple predictions for must_have category in week 1
    # @player gets 2 votes
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: user2, player: @player, season_type: "weekly", category: "must_have", week: 1)

    # player2 gets 1 vote
    Prediction.create!(user: @user, player: player2, season_type: "weekly", category: "must_have", week: 1)

    # Get top players for must_have category in week 1
    top_players = Prediction.top_players_by_category_for_week(1, "must_have", 10)
    top_players_array = top_players.to_a

    assert_equal 2, top_players_array.length

    # First result should be @player with 2 votes
    assert_equal @player.id, top_players_array.first.player_id
    assert_equal 2, top_players_array.first.count

    # Second result should be player2 with 1 vote
    assert_equal player2.id, top_players_array.second.player_id
    assert_equal 1, top_players_array.second.count
  end

  test "top_players_by_category_for_week should respect limit" do
    user2 = users(:two)  # Admin user

    # Create predictions that would exceed limit
    (1..5).each do |i|
      # Create a player with ID that doesn't conflict
      player = Player.create!(name: "Player #{i}", team: "Team #{i}", position: "FWD", fpl_id: 1000 + i)
      Prediction.create!(user: @user, player: player, season_type: "weekly", category: "must_have", week: 1)
    end

    # Test with limit of 3
    top_players = Prediction.top_players_by_category_for_week(1, "must_have", 3)
    assert_equal 3, top_players.to_a.length
  end
end
