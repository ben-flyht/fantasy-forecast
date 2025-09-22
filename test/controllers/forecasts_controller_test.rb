require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @forecaster_user = users(:one)  # Forecaster user
    @admin_user = users(:two)    # Admin user
    @player = players(:one)
    @other_player = players(:two)

    # Clear data to avoid conflicts
    Forecast.destroy_all
    Gameweek.destroy_all

    # Create gameweek for testing
    @gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: 1.week.ago,
      end_time: Time.current - 1.second,
      is_current: false,
      is_next: true,
      is_finished: false
    )

    @next_gameweek = @gameweek

    @forecast = Forecast.create!(
      user: @forecaster_user,
      player: @player,
      category: "target",
      gameweek: @gameweek
    )
  end

  # Tests for Forecaster users (can manage their own forecasts)
  test "forecaster should get index with their forecasts" do
    sign_in @forecaster_user
    get forecasts_url
    assert_response :success
  end

  test "forecaster should get new" do
    sign_in @forecaster_user
    get new_forecast_url
    assert_response :success
  end

  test "forecaster should create their own forecast" do
    sign_in @forecaster_user
    assert_difference("Forecast.count") do
      post forecasts_url, params: {
        forecast: {
          player_id: @other_player.id,
          category: "avoid"
        }
      }
    end

    assert_redirected_to forecast_url(Forecast.last)
  end

  test "forecaster should show their own forecast" do
    sign_in @forecaster_user
    get forecast_url(@forecast)
    assert_response :success
  end

  test "forecaster should get edit for their own forecast" do
    sign_in @forecaster_user
    get edit_forecast_url(@forecast)
    assert_response :success
  end

  test "forecaster should update their own forecast" do
    sign_in @forecaster_user
    patch forecast_url(@forecast), params: {
      forecast: {
        category: "avoid"
      }
    }
    assert_redirected_to forecast_url(@forecast)
  end

  test "forecaster should destroy their own forecast" do
    sign_in @forecaster_user
    assert_difference("Forecast.count", -1) do
      delete forecast_url(@forecast)
    end

    assert_redirected_to forecasts_url
  end

  test "forecaster should not edit other user's forecast" do
    other_forecast = Forecast.create!(
      user: @admin_user,
      player: @other_player,
      category: "target",
      gameweek: @gameweek
    )

    sign_in @forecaster_user
    get edit_forecast_url(other_forecast)
    assert_redirected_to forecasts_path
  end

  # Tests for Admin users
  test "admin should see all forecasts in index" do
    sign_in @admin_user
    get forecasts_url
    assert_response :success
  end

  test "admin can view any forecast" do
    sign_in @admin_user
    get forecast_url(@forecast)
    assert_response :success
  end

  test "admin cannot edit forecaster's forecast" do
    sign_in @admin_user
    get edit_forecast_url(@forecast)
    assert_redirected_to forecasts_path
  end

  test "admin cannot delete forecaster's forecast" do
    sign_in @admin_user
    assert_no_difference("Forecast.count") do
      delete forecast_url(@forecast)
    end
    assert_redirected_to forecasts_path
  end

  # Tests for unauthenticated users
  test "should not get index when not logged in" do
    get forecasts_url
    assert_redirected_to new_user_session_path
  end

  test "should not get new when not logged in" do
    get new_forecast_url
    assert_redirected_to new_user_session_path
  end

  # Test AJAX endpoints
  test "sync_all should update all forecasts for user" do
    sign_in @forecaster_user

    post sync_all_forecasts_url, params: {
      forecasts: {
        target: {
          goalkeeper: {
            "0" => @player.id.to_s
          }
        },
        avoid: {
          defender: {
            "0" => @other_player.id.to_s
          }
        }
      }
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal 2, json_response["count"]
  end

  test "update_forecast should update single forecast via AJAX" do
    sign_in @forecaster_user

    patch update_forecast_forecasts_url, params: {
      player_id: @other_player.id,
      category: "target",
      position: "forward"
    }, as: :turbo_stream

    assert_response :success
    assert Forecast.exists?(user: @forecaster_user, player: @other_player, category: "target")
  end

  test "update_forecast should replace selection in same slot without creating duplicates" do
    sign_in @forecaster_user

    # First, create a forecast for slot 0 of goalkeeper target
    patch update_forecast_forecasts_url, params: {
      player_id: @player.id,
      category: "target",
      position: "goalkeeper",
      slot: "0"
    }, as: :turbo_stream

    assert_response :success
    assert_equal 1, Forecast.where(user: @forecaster_user, gameweek: @next_gameweek).count
    assert Forecast.exists?(user: @forecaster_user, player: @player, category: "target")

    # Now change the selection in slot 0 to a different player
    patch update_forecast_forecasts_url, params: {
      player_id: @other_player.id,
      category: "target",
      position: "goalkeeper",
      slot: "0"
    }, as: :turbo_stream

    assert_response :success
    # Should still have only 1 forecast (old one replaced, not added)
    assert_equal 1, Forecast.where(user: @forecaster_user, gameweek: @next_gameweek).count
    # Should have the new player, not the old one
    assert Forecast.exists?(user: @forecaster_user, player: @other_player, category: "target")
    assert_not Forecast.exists?(user: @forecaster_user, player: @player, category: "target")
  end

  test "update_forecast should clear selection when player_id is empty" do
    sign_in @forecaster_user

    # First, create a forecast for slot 0 of goalkeeper target
    patch update_forecast_forecasts_url, params: {
      player_id: @player.id,
      category: "target",
      position: "goalkeeper",
      slot: "0"
    }, as: :turbo_stream

    assert_response :success
    assert_equal 1, Forecast.where(user: @forecaster_user, gameweek: @next_gameweek).count

    # Now clear the selection in slot 0 by sending empty player_id
    patch update_forecast_forecasts_url, params: {
      player_id: "",
      category: "target",
      position: "goalkeeper",
      slot: "0"
    }, as: :turbo_stream

    assert_response :success
    # Should have no forecasts after clearing
    assert_equal 0, Forecast.where(user: @forecaster_user, gameweek: @next_gameweek).count
  end
end
