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

    # Create bot user for rankings (ConsensusRanking requires bot forecasts with ranks)
    @bot_user = create_test_bot(User::BOT_USERNAME)
  end

  test "players index should not require authentication" do
    get players_path
    assert_response :success
    assert_includes response.body, "Player Rankings"
  end

  test "forecaster should access players index" do
    sign_in @forecaster_user
    get players_path
    assert_response :success
  end

  test "admin should access players index" do
    sign_in @admin_user
    get players_path
    assert_response :success
  end

  test "consensus should show forecasts data when available" do
    # Create bot forecasts with ranks (required for ConsensusRanking)
    Forecast.create!(user: @bot_user, player: @player, gameweek: @gameweek5, rank: 1)
    Forecast.create!(user: @bot_user, player: @player2, gameweek: @gameweek5, rank: 2)

    # Create human forecasts (votes)
    Forecast.create!(user: @forecaster_user, player: @player, gameweek: @gameweek5)
    Forecast.create!(user: @admin_user, player: @player, gameweek: @gameweek5)
    Forecast.create!(user: @forecaster_user, player: @player2, gameweek: @gameweek5)

    get players_path, params: { gameweek: 5, position: @player.position }
    assert_response :success

    # Should show player names and consensus scores
    assert_includes response.body, "Test Player"
  end

  test "consensus should filter by gameweek parameter" do
    # Create forecasts for different gameweeks
    Forecast.create!(user: @forecaster_user, player: @player, gameweek: @gameweek1)
    Forecast.create!(user: @forecaster_user, player: @player2, gameweek: @gameweek2)

    # Test gameweek 1
    get players_path, params: { gameweek: 1 }
    assert_response :success

    # Test gameweek 2
    get players_path, params: { gameweek: 2 }
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
    Forecast.create!(user: @forecaster_user, player: @player, gameweek: @gameweek5)  # goalkeeper
    Forecast.create!(user: @forecaster_user, player: midfielder, gameweek: @gameweek5)

    # Test no position filter
    get players_path, params: { gameweek: 5 }
    assert_response :success

    # Test goalkeeper filter
    get players_path, params: { gameweek: 5, position: "goalkeeper" }
    assert_response :success

    # Test midfielder filter
    get players_path, params: { gameweek: 5, position: "midfielder" }
    assert_response :success
  end

  test "consensus should default to next gameweek" do
    get players_path
    assert_response :success

    # Should see gameweek 2 (next gameweek) in page title or content
    assert_includes response.body, "Gameweek 2"
  end

  test "consensus should handle empty forecasts gracefully" do
    # No forecasts created - redirect to next gameweek
    get players_path, params: { gameweek: 10 }
    assert_response :redirect
  end

  test "weekly consensus alias should work" do
    get players_path(gameweek: 2)
    assert_response :success
    assert_includes response.body, "Player Rankings"
  end
end
