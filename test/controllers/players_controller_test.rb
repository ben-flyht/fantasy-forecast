require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @forecaster_user = users(:one)  # Forecaster user
    @admin_user = users(:two)    # Admin user
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

  test "players index should not require authentication" do
    get players_path
    assert_response :success
    assert_includes response.body, "Weekly Consensus Rankings"
  end

  test "forecaster should access players index" do
    sign_in @forecaster_user
    get players_path
    assert_response :success
    assert_includes response.body, "Weekly Consensus Rankings"
  end

  test "admin should access players index" do
    sign_in @admin_user
    get players_path
    assert_response :success
    assert_includes response.body, "Weekly Consensus Rankings"
  end

  test "consensus should show forecasts data when available" do
    # Create test forecasts
    Forecast.create!(user: @forecaster_user, player: @player, category: "target", gameweek: @gameweek5)
    Forecast.create!(user: @admin_user, player: @player, category: "target", gameweek: @gameweek5)
    Forecast.create!(user: @forecaster_user, player: @player2, category: "avoid", gameweek: @gameweek5)

    sign_in @forecaster_user
    get players_path, params: { week: 5, position: @player.position }
    assert_response :success

    # Should show player names and consensus scores
    assert_includes response.body, "Player One"
  end

  test "consensus should filter by week parameter" do
    # Create forecasts for different weeks
    Forecast.create!(user: @forecaster_user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @forecaster_user, player: @player2, category: "target", gameweek: @gameweek2)

    sign_in @forecaster_user

    # Test week 1
    get players_path, params: { week: 1 }
    assert_response :success

    # Test week 2
    get players_path, params: { week: 2 }
    assert_response :success
  end

  test "consensus should filter by position parameter" do
    # Create midfielder player
    midfielder = Player.create!(
      first_name: "Test",
      last_name: "Midfielder",
      team: @test_team,
      position: "midfielder",
      fpl_id: 999
    )

    # Create forecasts for different positions
    Forecast.create!(user: @forecaster_user, player: @player, category: "target", gameweek: @gameweek5)  # goalkeeper
    Forecast.create!(user: @forecaster_user, player: midfielder, category: "target", gameweek: @gameweek5)

    sign_in @forecaster_user

    # Test no position filter
    get players_path, params: { week: 5 }
    assert_response :success

    # Test goalkeeper filter
    get players_path, params: { week: 5, position: "GK" }
    assert_response :success

    # Test midfielder filter
    get players_path, params: { week: 5, position: "MID" }
    assert_response :success
  end

  test "consensus should default to next gameweek" do
    sign_in @forecaster_user
    get players_path
    assert_response :success

    # Should see week 2 (next gameweek) in page title or content
    assert_includes response.body, "Week 2"
  end

  test "consensus should handle empty forecasts gracefully" do
    # No forecasts created
    sign_in @forecaster_user
    get players_path, params: { week: 10 }
    assert_response :success

    # Should show empty state or no consensus message
    assert_includes response.body, "No consensus"
  end

  test "weekly consensus alias should work" do
    sign_in @forecaster_user
    get players_path(week: 5)
    assert_response :success
    assert_includes response.body, "Weekly Consensus Rankings"
  end
end
