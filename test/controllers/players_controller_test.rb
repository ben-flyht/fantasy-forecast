require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @player = players(:one)
    @admin_user = users(:two)  # Admin user from fixtures
    @prophet_user = users(:one)  # Prophet user from fixtures
  end

  # Tests accessible to all users
  test "anyone should get index" do
    get players_url
    assert_response :success
  end

  test "anyone should show player" do
    get player_url(@player)
    assert_response :success
  end

  # Tests for admin access
  test "admin should get new" do
    sign_in @admin_user
    get new_player_url
    assert_response :success
  end

  test "admin should create player" do
    sign_in @admin_user
    assert_difference("Player.count") do
      post players_url, params: {
        player: {
          name: "New Test Player",
          team: "Liverpool",
          position: "GK",
          bye_week: 8,
          fpl_id: 999
        }
      }
    end

    assert_redirected_to player_url(Player.last)
  end

  test "admin should get edit" do
    sign_in @admin_user
    get edit_player_url(@player)
    assert_response :success
  end

  test "admin should update player" do
    sign_in @admin_user
    patch player_url(@player), params: {
      player: {
        name: "Updated Player",
        team: @player.team,
        position: @player.position,
        bye_week: @player.bye_week,
        fpl_id: @player.fpl_id
      }
    }
    assert_redirected_to player_url(@player)
  end

  test "admin should destroy player" do
    sign_in @admin_user
    assert_difference("Player.count", -1) do
      delete player_url(@player)
    end

    assert_redirected_to players_url
  end

  # Tests for prophet access restrictions
  test "prophet should be redirected from new" do
    sign_in @prophet_user
    get new_player_url
    assert_redirected_to players_url
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  test "prophet should not create player" do
    sign_in @prophet_user
    assert_no_difference("Player.count") do
      post players_url, params: {
        player: {
          name: "New Test Player",
          team: "Liverpool",
          position: "GK",
          bye_week: 8,
          fpl_id: 999
        }
      }
    end

    assert_redirected_to players_url
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  test "prophet should be redirected from edit" do
    sign_in @prophet_user
    get edit_player_url(@player)
    assert_redirected_to players_url
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  test "prophet should not update player" do
    sign_in @prophet_user
    patch player_url(@player), params: {
      player: {
        name: "Updated Player",
        team: @player.team,
        position: @player.position,
        bye_week: @player.bye_week,
        fpl_id: @player.fpl_id
      }
    }
    assert_redirected_to players_url
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  test "prophet should not destroy player" do
    sign_in @prophet_user
    assert_no_difference("Player.count") do
      delete player_url(@player)
    end

    assert_redirected_to players_url
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  # Tests for unauthenticated access restrictions
  test "guest should be redirected from new" do
    get new_player_url
    assert_redirected_to new_user_session_url
    assert_equal "You need to sign in or sign up before continuing.", flash[:alert]
  end

  test "guest should not create player" do
    assert_no_difference("Player.count") do
      post players_url, params: {
        player: {
          name: "New Test Player",
          team: "Liverpool",
          position: "GK",
          bye_week: 8,
          fpl_id: 999
        }
      }
    end

    assert_redirected_to new_user_session_url
    assert_equal "You need to sign in or sign up before continuing.", flash[:alert]
  end
end
