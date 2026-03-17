require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @player = players(:goalkeeper)
    @player2 = players(:midfielder)

    # Create test team
    @test_team = Team.create!(name: "Test Team", short_name: "TST", fpl_id: 96)

    # Clear data to avoid conflicts
    Forecast.destroy_all
    Gameweek.destroy_all

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

    @gameweek5 = Gameweek.create!(
      fpl_id: 5,
      name: "Gameweek 5",
      start_time: 4.weeks.from_now,
      end_time: 5.weeks.from_now - 1.second,
      is_current: false,
      is_next: false,
      is_finished: false
    )
  end

  test "players index should be accessible" do
    get root_path
    assert_response :success
  end

  test "should show forecasts data when available" do
    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1)
    Forecast.create!(player: @player2, gameweek: @gameweek5, rank: 2)

    get gameweek_position_path(gameweek: 5, position: "#{@player.position}s")
    assert_response :success
    assert_includes response.body, @player.short_name
  end

  test "should filter by gameweek parameter" do
    Forecast.create!(player: @player, gameweek: @gameweek1, rank: 1)
    Forecast.create!(player: @player2, gameweek: @gameweek2, rank: 1)

    get gameweek_position_path(gameweek: 1, position: "forwards")
    assert_response :success

    get gameweek_position_path(gameweek: 2, position: "forwards")
    assert_response :success
  end

  test "should filter by position parameter" do
    midfielder = Player.create!(
      first_name: "Test", last_name: "Midfielder",
      team: @test_team, position: "midfielder", fpl_id: 999
    )

    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1)
    Forecast.create!(player: midfielder, gameweek: @gameweek5, rank: 1)

    get gameweek_position_path(gameweek: 5, position: "forwards")
    assert_response :success

    get gameweek_position_path(gameweek: 5, position: "goalkeepers")
    assert_response :success

    get gameweek_position_path(gameweek: 5, position: "midfielders")
    assert_response :success
  end

  test "should redirect old query-param URLs to clean URLs" do
    get root_path, params: { gameweek: 5, position: "midfielder" }
    assert_response :moved_permanently
    assert_redirected_to gameweek_position_path(gameweek: 5, position: "midfielders")
  end

  test "should default to next gameweek" do
    get root_path
    assert_response :success

    # Should see gameweek 2 (next gameweek) in page title or content
    assert_includes response.body, "Gameweek 2"
  end

  test "should handle invalid gameweek gracefully" do
    get gameweek_position_path(gameweek: 10, position: "forwards")
    assert_response :redirect
  end

  test "old /players path should redirect to root" do
    get "/players"
    assert_response :redirect
    assert_redirected_to root_path
  end

  test "should show player page with slugged URL" do
    get player_path(@player)
    assert_response :success
    assert_includes response.body, @player.full_name
  end

  test "should redirect old-style numeric ID to slugged URL" do
    get "/players/#{@player.id}"
    assert_response :moved_permanently
    assert_redirected_to player_path(@player)
  end

  test "should redirect incorrect slug to canonical URL" do
    get "/players/wrong-slug-#{@player.fpl_id}"
    assert_response :moved_permanently
    assert_redirected_to player_path(@player)
  end

  test "should return 404 for non-existent player" do
    get "/players/non-existent-99999"
    assert_response :not_found
  end
end
