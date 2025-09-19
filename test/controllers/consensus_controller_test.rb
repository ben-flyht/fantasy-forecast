require "test_helper"

class ConsensusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @prophet_user = users(:one)  # Prophet user
    @admin_user = users(:two)    # Admin user
    @player = players(:one)
    @player2 = players(:two)

    # Clear data to avoid conflicts
    Prediction.destroy_all
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

  test "weekly consensus should require authentication" do
    get consensus_weekly_path
    assert_redirected_to new_user_session_path
  end

  test "rest_of_season consensus should require authentication" do
    get consensus_rest_of_season_path
    assert_redirected_to new_user_session_path
  end

  test "prophet should get weekly consensus with default week" do
    sign_in @prophet_user

    # Create some test predictions
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek2)

    get consensus_weekly_path
    assert_response :success
    assert_equal 1, assigns(:week)
    assert_not_nil assigns(:consensus_data)
    assert_not_nil assigns(:available_weeks)
    assert_equal "Weekly Consensus - Week 1", assigns(:page_title)
  end

  test "prophet should get weekly consensus with specific week" do
    sign_in @prophet_user

    # Create test predictions for week 3
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek2)

    get consensus_weekly_path(week: 3)
    assert_response :success
    assert_equal 3, assigns(:week)
    assert_not_nil assigns(:consensus_data)
    assert_equal "Weekly Consensus - Week 3", assigns(:page_title)
  end

  test "weekly consensus should load correct consensus data" do
    sign_in @prophet_user

    # Create predictions for week 1
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek1)
    Prediction.create!(user: @admin_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek1)
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "weekly", category: "avoid", gameweek: @gameweek1)

    get consensus_weekly_path(week: 1)
    assert_response :success

    consensus_data = assigns(:consensus_data)
    assert_not_nil consensus_data

    # Should have data organized by category
    assert consensus_data.key?("must_have")
    assert consensus_data.key?("better_than_expected")
    assert consensus_data.key?("worse_than_expected")

    # Must have should have @player with 2 votes
    must_have_players = consensus_data["must_have"]
    assert_equal 1, must_have_players.length
    assert_equal @player, must_have_players.first[:player]
    assert_equal 2, must_have_players.first[:votes]

    # Better than expected should have @player2 with 1 vote
    better_players = consensus_data["better_than_expected"]
    assert_equal 1, better_players.length
    assert_equal @player2, better_players.first[:player]
    assert_equal 1, better_players.first[:votes]

    # Worse than expected should be empty
    assert_equal 0, consensus_data["worse_than_expected"].length
  end

  test "weekly consensus should show available weeks with predictions" do
    sign_in @prophet_user

    # Create predictions for specific gameweeks
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek2)
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "weekly", category: "target", gameweek: @gameweek5)

    get consensus_weekly_path
    assert_response :success

    available_weeks = assigns(:available_weeks)
    assert_includes available_weeks, 2
    assert_includes available_weeks, 5
  end

  test "admin should get weekly consensus" do
    sign_in @admin_user

    # Create test predictions
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek2)

    get consensus_weekly_path
    assert_response :success
    assert_not_nil assigns(:consensus_data)
  end

  test "prophet should get rest_of_season consensus" do
    sign_in @prophet_user

    # Create some test predictions
    Prediction.create!(user: @prophet_user, player: @player, season_type: "rest_of_season", category: "target")

    get consensus_rest_of_season_path
    assert_response :success
    assert_not_nil assigns(:consensus_data)
    assert_equal "Rest of Season Consensus", assigns(:page_title)
  end

  test "rest_of_season consensus should load correct data" do
    sign_in @prophet_user

    # Create rest of season predictions
    Prediction.create!(user: @prophet_user, player: @player, season_type: "rest_of_season", category: "target")
    Prediction.create!(user: @admin_user, player: @player, season_type: "rest_of_season", category: "target")
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "rest_of_season", category: "avoid")

    get consensus_rest_of_season_path
    assert_response :success

    consensus_data = assigns(:consensus_data)
    assert_not_nil consensus_data

    # Should have data organized by category
    assert consensus_data.key?("must_have")
    assert consensus_data.key?("better_than_expected")
    assert consensus_data.key?("worse_than_expected")

    # Must have should have @player with 2 votes
    must_have_players = consensus_data["must_have"]
    assert_equal 1, must_have_players.length
    assert_equal @player, must_have_players.first[:player]
    assert_equal 2, must_have_players.first[:votes]

    # Worse than expected should have @player2 with 1 vote
    worse_players = consensus_data["worse_than_expected"]
    assert_equal 1, worse_players.length
    assert_equal @player2, worse_players.first[:player]
    assert_equal 1, worse_players.first[:votes]

    # Better than expected should be empty
    assert_equal 0, consensus_data["better_than_expected"].length
  end

  test "admin should get rest_of_season consensus" do
    sign_in @admin_user

    # Create test predictions
    Prediction.create!(user: @prophet_user, player: @player, season_type: "rest_of_season", category: "target")

    get consensus_rest_of_season_path
    assert_response :success
    assert_not_nil assigns(:consensus_data)
  end

  test "weekly consensus should handle empty data gracefully" do
    sign_in @prophet_user

    # No predictions created
    get consensus_weekly_path(week: 1)
    assert_response :success

    consensus_data = assigns(:consensus_data)
    assert_not_nil consensus_data

    # Should still have category structure but empty arrays
    assert consensus_data.key?("must_have")
    assert consensus_data.key?("better_than_expected")
    assert consensus_data.key?("worse_than_expected")

    assert_equal 0, consensus_data["must_have"].length
    assert_equal 0, consensus_data["better_than_expected"].length
    assert_equal 0, consensus_data["worse_than_expected"].length
  end

  test "rest_of_season consensus should handle empty data gracefully" do
    sign_in @prophet_user

    # No predictions created
    get consensus_rest_of_season_path
    assert_response :success

    consensus_data = assigns(:consensus_data)
    assert_not_nil consensus_data

    # Should still have category structure but empty arrays
    assert consensus_data.key?("must_have")
    assert consensus_data.key?("better_than_expected")
    assert consensus_data.key?("worse_than_expected")

    assert_equal 0, consensus_data["must_have"].length
    assert_equal 0, consensus_data["better_than_expected"].length
    assert_equal 0, consensus_data["worse_than_expected"].length
  end

  test "weekly consensus should filter predictions by week correctly" do
    sign_in @prophet_user

    # Create predictions for different gameweeks
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek1)
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "weekly", category: "target", gameweek: @gameweek2)

    # Request week 1 consensus
    get consensus_weekly_path(week: 1)
    assert_response :success

    consensus_data = assigns(:consensus_data)
    must_have_players = consensus_data["must_have"]

    # Should only show @player (gameweek 1), not @player2 (gameweek 2)
    assert_equal 1, must_have_players.length
    assert_equal @player, must_have_players.first[:player]
  end

  test "consensus should not include weekly predictions in rest_of_season view" do
    sign_in @prophet_user

    # Create both weekly and rest of season predictions
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "target", gameweek: @gameweek2)
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "rest_of_season", category: "target")

    get consensus_rest_of_season_path
    assert_response :success

    consensus_data = assigns(:consensus_data)
    must_have_players = consensus_data["must_have"]

    # Should only show @player2 (rest of season), not @player (weekly)
    assert_equal 1, must_have_players.length
    assert_equal @player2, must_have_players.first[:player]
  end

  test "available_weeks should default to 1-38 when no predictions exist" do
    sign_in @prophet_user

    # No predictions created
    get consensus_weekly_path
    assert_response :success

    available_weeks = assigns(:available_weeks)
    assert_equal (1..38).to_a, available_weeks
  end
end
