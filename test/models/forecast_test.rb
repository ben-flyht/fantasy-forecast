require "test_helper"

class ForecastTest < ActiveSupport::TestCase
  def setup
    # Clear forecasts to avoid fixture conflicts
    Forecast.destroy_all
    Gameweek.destroy_all
    @user = users(:one)  # Forecaster user
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
    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "target"
    )
    assert forecast.valid?
    assert_equal @user, forecast.user
  end

  test "should belong to player" do
    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "target"
    )
    assert forecast.valid?
    assert_equal @player, forecast.player
  end

  test "should belong to gameweek" do
    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "target"
    )
    assert forecast.valid?
    assert_equal @next_gameweek, forecast.gameweek
  end

  test "should require category" do
    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek
    )
    assert_not forecast.valid?
    assert_includes forecast.errors[:category], "can't be blank"
  end

  test "should validate category enum" do
    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek
    )

    # Valid categories
    forecast.category = "target"
    assert forecast.valid?
    assert forecast.target?

    forecast.category = "avoid"
    assert forecast.valid?
    assert forecast.avoid?

    # Invalid category
    assert_raises(ArgumentError) do
      forecast.category = "invalid"
    end
  end

  test "should enforce uniqueness constraint" do
    # Create first forecast
    forecast1 = Forecast.create!(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "target"
    )

    # Try to create duplicate (same user, player, gameweek)
    forecast2 = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "avoid"  # Different category but still duplicate
    )

    assert_not forecast2.valid?
    assert_includes forecast2.errors[:user_id], "has already been taken"
  end

  test "should allow same user to forecast same player for different gameweeks" do
    # Create gameweek 2
    gameweek2 = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current + 2.weeks,
      is_next: false
    )

    # Create forecast for gameweek 1
    forecast1 = Forecast.create!(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "target"
    )

    # Create forecast for gameweek 2 - should be valid
    forecast2 = Forecast.new(
      user: @user,
      player: @player,
      gameweek: gameweek2,
      category: "target"
    )

    assert forecast2.valid?
  end

  test "scopes should work correctly" do
    player2 = players(:two)
    user2 = users(:two)

    forecast1 = Forecast.create!(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "target"
    )

    forecast2 = Forecast.create!(
      user: user2,
      player: player2,
      gameweek: @next_gameweek,
      category: "avoid"
    )

    # Test by_category scope
    assert_includes Forecast.by_category("target"), forecast1
    assert_not_includes Forecast.by_category("target"), forecast2

    # Test for_player scope
    assert_includes Forecast.for_player(@player.id), forecast1
    assert_not_includes Forecast.for_player(@player.id), forecast2

    # Test for_user scope
    assert_includes Forecast.for_user(@user.id), forecast1
    assert_not_includes Forecast.for_user(@user.id), forecast2

    # Test by_gameweek scope
    assert_includes Forecast.by_gameweek(@next_gameweek.id), forecast1
    assert_includes Forecast.by_gameweek(@next_gameweek.id), forecast2
  end

  test "by_week scope should work with gameweek fpl_id" do
    forecast = Forecast.create!(
      user: @user,
      player: @player,
      gameweek: @next_gameweek,
      category: "target"
    )

    # Test by_week scope using fpl_id
    assert_includes Forecast.by_week(1), forecast
    assert_not_includes Forecast.by_week(2), forecast
  end

  test "consensus_scores_for_week should aggregate forecasts correctly" do
    user2 = users(:two)
    player2 = players(:two)

    # Create multiple forecasts
    Forecast.create!(user: @user, player: @player, gameweek: @next_gameweek, category: "target")
    Forecast.create!(user: user2, player: @player, gameweek: @next_gameweek, category: "target")
    Forecast.create!(user: @user, player: player2, gameweek: @next_gameweek, category: "avoid")

    results = Forecast.consensus_scores_for_week(1)

    # Check player1 has consensus score of +2 (two targets)
    player1_result = results.find { |r| r.player_id == @player.id }
    assert_equal 2, player1_result.consensus_score
    assert_equal 2, player1_result.total_forecasts

    # Check player2 has consensus score of -1 (one avoid)
    player2_result = results.find { |r| r.player_id == player2.id }
    assert_equal(-1, player2_result.consensus_score)
    assert_equal 1, player2_result.total_forecasts
  end

  test "consensus_scores_for_week_by_position should filter by position" do
    mid_team = Team.create!(name: "MID Team", short_name: "MID", fpl_id: 98)
    midfielder = Player.create!(
      first_name: "Test",
      last_name: "Midfielder",
      team: mid_team,
      position: "midfielder",
      fpl_id: 999
    )

    Forecast.create!(user: @user, player: @player, gameweek: @next_gameweek, category: "target")
    Forecast.create!(user: @user, player: midfielder, gameweek: @next_gameweek, category: "target")

    # Filter by goalkeeper position (assuming @player is a goalkeeper)
    gk_results = Forecast.consensus_scores_for_week_by_position(1, "goalkeeper")
    assert_equal 1, gk_results.length
    assert_equal @player.id, gk_results.first.player_id

    # Filter by midfielder position
    mid_results = Forecast.consensus_scores_for_week_by_position(1, "midfielder")
    assert_equal 1, mid_results.length
    assert_equal midfielder.id, mid_results.first.player_id
  end

  test "forecast should automatically assign next gameweek" do
    forecast = Forecast.new(
      user: @user,
      player: @player,
      category: "target"
    )

    assert forecast.valid?
    assert_equal @next_gameweek, forecast.gameweek
  end

  test "forecast with manually set gameweek should be preserved" do
    other_gameweek = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current + 2.weeks
    )

    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: other_gameweek,
      category: "target"
    )

    assert forecast.valid?
    assert_equal other_gameweek, forecast.gameweek
  end

  test "assign_next_gameweek! class method should return next gameweek id" do
    result = Forecast.assign_next_gameweek!
    assert_equal @next_gameweek.id, result
  end

  test "assign_next_gameweek! class method should return nil when no next gameweek" do
    @next_gameweek.update!(is_next: false)
    result = Forecast.assign_next_gameweek!
    assert_nil result
  end
end
