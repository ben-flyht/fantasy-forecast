require "test_helper"

class PredictionTest < ActiveSupport::TestCase
  def setup
    # Clear predictions to avoid fixture conflicts
    Prediction.destroy_all
    Gameweek.destroy_all
    @user = users(:one)  # Prophet user
    @player = players(:one)

    # Create a next gameweek for auto-assignment tests
    @next_gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current + 1.week,
      is_next: true
    )
  end

  test "should belong to user" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target"
    )
    assert prediction.valid?
    assert_equal @user, prediction.user
  end

  test "should belong to player" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target"
    )
    assert prediction.valid?
    assert_equal @player, prediction.player
  end

  test "should require season_type" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      category: "target"
    )
    assert_not prediction.valid?
    assert_includes prediction.errors[:season_type], "can't be blank"
  end

  test "should require category" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly"
    )
    assert_not prediction.valid?
    assert_includes prediction.errors[:category], "can't be blank"
  end

  test "should require gameweek when season_type is weekly" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target"
    )
    # Gameweek should be auto-assigned, so it should be valid
    assert prediction.valid?
    assert_equal @next_gameweek, prediction.gameweek
  end

  test "should not require week when season_type is rest_of_season" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "rest_of_season",
      category: "target"
    )
    assert prediction.valid?
  end

  test "should enforce uniqueness constraint" do
    # Create first prediction
    prediction1 = Prediction.create!(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target",
          )

    # Try to create duplicate prediction
    prediction2 = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "avoid",  # Different category, but same user/player/week/season_type
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
      category: "target",
          )

    # Different user should be able to predict same player/week
    prediction2 = Prediction.new(
      user: user2,
      player: @player,
      season_type: "weekly",
      category: "avoid",
          )

    assert prediction2.valid?
  end

  test "should allow same user to predict same player for different season types" do
    # Create first prediction for weekly
    prediction1 = Prediction.create!(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target"
    )

    # Same user should be able to predict same player for rest of season
    prediction2 = Prediction.new(
      user: @user,
      player: @player,
      season_type: "rest_of_season",
      category: "avoid"
    )

    assert prediction2.valid?
  end

  test "should validate season_type enum" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      category: "target",
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
      category: "target"
    )

    pred2 = Prediction.create!(
      user: @user,
      player: players(:two),
      season_type: "rest_of_season",
      category: "avoid"
    )

    # Test scopes
    assert_includes Prediction.by_category("must_have"), pred1
    assert_not_includes Prediction.by_category("must_have"), pred2

    assert_includes Prediction.by_week(@next_gameweek.fpl_id), pred1
    assert_not_includes Prediction.by_week(@next_gameweek.fpl_id), pred2

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
      category: "target"
    )

    pred2 = Prediction.create!(
      user: user2,
      player: player2,
      season_type: "weekly",
      category: "avoid"
    )

    pred3 = Prediction.create!(
      user: @user,
      player: @player,  # Changed to use @player so the for_player scope will include it
      season_type: "rest_of_season",
      category: "avoid"
    )

    # Test for_week scope - both weekly predictions should be in the same week now
    assert_includes Prediction.for_week(@next_gameweek.fpl_id), pred1
    assert_includes Prediction.for_week(@next_gameweek.fpl_id), pred2  # Now included since all weekly predictions use same week
    assert_not_includes Prediction.for_week(@next_gameweek.fpl_id), pred3

    # Test for_season_type scope
    assert_includes Prediction.for_season_type("weekly"), pred1
    assert_includes Prediction.for_season_type("weekly"), pred2
    assert_not_includes Prediction.for_season_type("weekly"), pred3

    # Test for_player scope
    assert_includes Prediction.for_player(@player.id), pred1
    assert_not_includes Prediction.for_player(@player.id), pred2
    assert_includes Prediction.for_player(@player.id), pred3

    # Test for_user scope
    assert_includes Prediction.for_user(@user.id), pred1
    assert_not_includes Prediction.for_user(@user.id), pred2
    assert_includes Prediction.for_user(@user.id), pred3
  end

  test "consensus_for_week should aggregate predictions correctly" do
    user2 = users(:two)  # Admin user
    player2 = players(:two)

    # Create predictions for current gameweek
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "target")
    Prediction.create!(user: user2, player: @player, season_type: "weekly", category: "target")
    Prediction.create!(user: @user, player: player2, season_type: "weekly", category: "avoid")

    consensus = Prediction.consensus_for_week(@next_gameweek.fpl_id)
    consensus_array = consensus.to_a

    # Should have 2 results for current gameweek
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
    Prediction.create!(user: @user, player: @player, season_type: "rest_of_season", category: "target")
    Prediction.create!(user: user2, player: @player, season_type: "rest_of_season", category: "target")
    Prediction.create!(user: @user, player: player2, season_type: "rest_of_season", category: "avoid")

    # Create weekly prediction (should not be included)
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "target")

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

    # Create multiple predictions for must_have category in current gameweek
    # @player gets 2 votes
    Prediction.create!(user: @user, player: @player, season_type: "weekly", category: "target")
    Prediction.create!(user: user2, player: @player, season_type: "weekly", category: "target")

    # player2 gets 1 vote
    Prediction.create!(user: @user, player: player2, season_type: "weekly", category: "target")

    # Get top players for must_have category in current gameweek
    top_players = Prediction.top_players_by_category_for_week(@next_gameweek.fpl_id, "must_have", 10)
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
      Prediction.create!(user: @user, player: player, season_type: "weekly", category: "target")
    end

    # Test with limit of 3
    top_players = Prediction.top_players_by_category_for_week(@next_gameweek.fpl_id, "must_have", 3)
    assert_equal 3, top_players.to_a.length
  end

  # Tests for gameweek auto-assignment functionality
  test "weekly prediction should automatically assign next gameweek" do
    # Use the existing next gameweek from setup

    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target"
    )

    assert prediction.valid?
    assert_equal @next_gameweek, prediction.gameweek
  end

  test "weekly prediction should require gameweek to be present" do
    # No next gameweek available
    Gameweek.update_all(is_next: false)

    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target"
    )

    assert_not prediction.valid?
    assert_includes prediction.errors[:gameweek], "can't be blank"
  end

  test "rest_of_season prediction should not require gameweek" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "rest_of_season",
      category: "target"
    )

    assert prediction.valid?
    assert_nil prediction.gameweek
  end

  test "should belong to gameweek when gameweek is assigned" do
    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target"
    )

    prediction.valid? # Trigger validation to assign gameweek
    assert_equal @next_gameweek, prediction.gameweek
  end

  test "assign_next_gameweek! class method should return next gameweek id" do
    assert_equal @next_gameweek.id, Prediction.assign_next_gameweek!
  end

  test "assign_next_gameweek! class method should return nil when no next gameweek" do
    Gameweek.update_all(is_next: false)
    assert_nil Prediction.assign_next_gameweek!
  end

  test "prediction with manually set gameweek should be preserved for weekly predictions" do
    # Create a different gameweek to test manual assignment
    manual_gameweek = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current,
      is_current: true
    )

    prediction = Prediction.new(
      user: @user,
      player: @player,
      season_type: "weekly",
      category: "target",
      gameweek: manual_gameweek  # Manually set gameweek
    )

    prediction.valid? # Trigger validation
    # Should preserve the manually set gameweek
    assert_equal manual_gameweek, prediction.gameweek
  end
end
