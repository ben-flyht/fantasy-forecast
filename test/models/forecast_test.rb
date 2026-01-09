require "test_helper"

class ForecastTest < ActiveSupport::TestCase
  def setup
    # Clear forecasts to avoid fixture conflicts
    Forecast.destroy_all
    Gameweek.destroy_all
    @player = players(:midfielder)
    @player2 = players(:midfielder_two)

    # Create a next gameweek for auto-assignment tests
    @next_gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current + 1.week,
      is_next: true
    )
  end

  test "should belong to player" do
    forecast = Forecast.new(
      player: @player,
      gameweek: @next_gameweek,
      rank: 1
    )
    assert forecast.valid?
    assert_equal @player, forecast.player
  end

  test "should belong to gameweek" do
    forecast = Forecast.new(
      player: @player,
      gameweek: @next_gameweek,
      rank: 1
    )
    assert forecast.valid?
    assert_equal @next_gameweek, forecast.gameweek
  end

  test "should enforce uniqueness constraint on player and gameweek" do
    # Create first forecast
    Forecast.create!(
      player: @player,
      gameweek: @next_gameweek,
      rank: 1
    )

    # Try to create duplicate (same player, gameweek)
    forecast2 = Forecast.new(
      player: @player,
      gameweek: @next_gameweek,
      rank: 2
    )

    assert_not forecast2.valid?
    assert_includes forecast2.errors[:player_id], "has already been taken"
  end

  test "should allow same player to have forecasts for different gameweeks" do
    # Create gameweek 2
    gameweek2 = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current + 2.weeks,
      is_next: false
    )

    # Create forecast for gameweek 1
    Forecast.create!(
      player: @player,
      gameweek: @next_gameweek,
      rank: 1
    )

    # Create forecast for gameweek 2 - should be valid
    forecast2 = Forecast.new(
      player: @player,
      gameweek: gameweek2,
      rank: 1
    )

    assert forecast2.valid?
  end

  test "scopes should work correctly" do
    forecast1 = Forecast.create!(
      player: @player,
      gameweek: @next_gameweek,
      rank: 1
    )

    forecast2 = Forecast.create!(
      player: @player2,
      gameweek: @next_gameweek,
      rank: 2
    )

    # Test for_player scope
    assert_includes Forecast.for_player(@player.id), forecast1
    assert_not_includes Forecast.for_player(@player.id), forecast2

    # Test by_gameweek scope
    assert_includes Forecast.by_gameweek(@next_gameweek.id), forecast1
    assert_includes Forecast.by_gameweek(@next_gameweek.id), forecast2

    # Test ranked scope
    assert_includes Forecast.ranked, forecast1
    assert_includes Forecast.ranked, forecast2
  end

  test "by_week scope should work with gameweek fpl_id" do
    forecast = Forecast.create!(
      player: @player,
      gameweek: @next_gameweek,
      rank: 1
    )

    # Test by_week scope using fpl_id
    assert_includes Forecast.by_week(1), forecast
    assert_not_includes Forecast.by_week(2), forecast
  end

  test "forecast should automatically assign next gameweek" do
    forecast = Forecast.new(
      player: @player,
      rank: 1
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
      player: @player,
      gameweek: other_gameweek,
      rank: 1
    )

    assert forecast.valid?
    assert_equal other_gameweek, forecast.gameweek
  end

  test "by_rank scope should order by rank ascending" do
    forecast2 = Forecast.create!(player: @player2, gameweek: @next_gameweek, rank: 2)
    forecast1 = Forecast.create!(player: @player, gameweek: @next_gameweek, rank: 1)

    ranked = Forecast.by_rank.to_a
    assert_equal forecast1, ranked.first
    assert_equal forecast2, ranked.second
  end
end
