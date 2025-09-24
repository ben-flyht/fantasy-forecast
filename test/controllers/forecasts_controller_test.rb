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

    assert_redirected_to new_forecast_url
  end

  # Tests for unauthenticated users
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
