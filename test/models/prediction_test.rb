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
end
