require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @player = players(:one)
    @player2 = players(:two)

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
    # Create bot forecasts with ranks
    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1)
    Forecast.create!(player: @player2, gameweek: @gameweek5, rank: 2)

    get root_path, params: { gameweek: 5, position: @player.position }
    assert_response :success

    # Should show player names
    assert_includes response.body, "Test Player"
  end

  test "should filter by gameweek parameter" do
    # Create forecasts for different gameweeks
    Forecast.create!(player: @player, gameweek: @gameweek1, rank: 1)
    Forecast.create!(player: @player2, gameweek: @gameweek2, rank: 1)

    # Test gameweek 1
    get root_path, params: { gameweek: 1 }
    assert_response :success

    # Test gameweek 2
    get root_path, params: { gameweek: 2 }
    assert_response :success
  end

  test "should filter by position parameter" do
    # Create midfielder player
    midfielder = Player.create!(
      first_name: "Test",
      last_name: "Midfielder",
      team: @test_team,
      position: "midfielder",
      fpl_id: 999
    )

    # Create forecasts for different positions
    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1)
    Forecast.create!(player: midfielder, gameweek: @gameweek5, rank: 1)

    # Test no position filter (defaults to forward)
    get root_path, params: { gameweek: 5 }
    assert_response :success

    # Test goalkeeper filter
    get root_path, params: { gameweek: 5, position: "goalkeeper" }
    assert_response :success

    # Test midfielder filter
    get root_path, params: { gameweek: 5, position: "midfielder" }
    assert_response :success
  end

  test "should default to next gameweek" do
    get root_path
    assert_response :success

    # Should see gameweek 2 (next gameweek) in page title or content
    assert_includes response.body, "Gameweek 2"
  end

  test "should handle invalid gameweek gracefully" do
    # No such gameweek - redirect to next gameweek
    get root_path, params: { gameweek: 10 }
    assert_response :redirect
  end

  test "old /players path should redirect to root" do
    get "/players"
    assert_response :redirect
    assert_redirected_to root_path
  end
end
