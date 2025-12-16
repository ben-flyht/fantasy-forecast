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
      gameweek: @next_gameweek
    )
    assert forecast.valid?
    assert_equal @user, forecast.user
  end

  test "should belong to player" do
    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek
    )
    assert forecast.valid?
    assert_equal @player, forecast.player
  end

  test "should belong to gameweek" do
    forecast = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek
    )
    assert forecast.valid?
    assert_equal @next_gameweek, forecast.gameweek
  end

  test "should enforce uniqueness constraint" do
    # Create first forecast
    forecast1 = Forecast.create!(
      user: @user,
      player: @player,
      gameweek: @next_gameweek
    )

    # Try to create duplicate (same user, player, gameweek)
    forecast2 = Forecast.new(
      user: @user,
      player: @player,
      gameweek: @next_gameweek
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
      gameweek: @next_gameweek
    )

    # Create forecast for gameweek 2 - should be valid
    forecast2 = Forecast.new(
      user: @user,
      player: @player,
      gameweek: gameweek2
    )

    assert forecast2.valid?
  end

  test "scopes should work correctly" do
    player2 = players(:two)
    user2 = users(:two)

    forecast1 = Forecast.create!(
      user: @user,
      player: @player,
      gameweek: @next_gameweek
    )

    forecast2 = Forecast.create!(
      user: user2,
      player: player2,
      gameweek: @next_gameweek
    )

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
      gameweek: @next_gameweek
    )

    # Test by_week scope using fpl_id
    assert_includes Forecast.by_week(1), forecast
    assert_not_includes Forecast.by_week(2), forecast
  end

  test "forecast should automatically assign next gameweek" do
    forecast = Forecast.new(
      user: @user,
      player: @player
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
      gameweek: other_gameweek
    )

    assert forecast.valid?
    assert_equal other_gameweek, forecast.gameweek
  end
end
