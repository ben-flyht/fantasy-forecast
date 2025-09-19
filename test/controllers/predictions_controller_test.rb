require "test_helper"

class PredictionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @prophet_user = users(:one)  # Prophet user
    @admin_user = users(:two)    # Admin user
    @player = players(:one)
    @other_player = players(:two)

    # Clear data to avoid conflicts
    Prediction.destroy_all
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

    @prediction = Prediction.create!(
      user: @prophet_user,
      player: @player,
      season_type: "weekly",
      category: "target",
      gameweek: @gameweek
    )
  end

  # Tests for Prophet users (can manage their own predictions)
  test "prophet should get index with their predictions" do
    sign_in @prophet_user
    get predictions_url
    assert_response :success
  end

  test "prophet should get new" do
    sign_in @prophet_user
    get new_prediction_url
    assert_response :success
  end

  test "prophet should create their own prediction" do
    sign_in @prophet_user
    assert_difference("Prediction.count") do
      post predictions_url, params: {
        prediction: {
          player_id: @other_player.id,
          season_type: "weekly",
          category: "avoid"
        }
      }
    end

    created_prediction = Prediction.last
    assert_equal @prophet_user, created_prediction.user
    assert_redirected_to prediction_url(created_prediction)
  end

  test "prophet should show their own prediction" do
    sign_in @prophet_user
    get prediction_url(@prediction)
    assert_response :success
  end

  test "prophet should get edit for their own prediction" do
    sign_in @prophet_user
    get edit_prediction_url(@prediction)
    assert_response :success
  end

  test "prophet should update their own prediction" do
    sign_in @prophet_user
    patch prediction_url(@prediction), params: {
      prediction: {
        player_id: @prediction.player_id,
        season_type: @prediction.season_type,
        category: "avoid"
      }
    }
    assert_redirected_to prediction_url(@prediction)

    @prediction.reload
    assert_equal "better_than_expected", @prediction.category
  end

  test "prophet should destroy their own prediction" do
    sign_in @prophet_user
    assert_difference("Prediction.count", -1) do
      delete prediction_url(@prediction)
    end

    assert_redirected_to predictions_url
  end

  # Tests for Prophet trying to access other user's predictions
  test "prophet cannot edit another user's prediction" do
    other_user_prediction = Prediction.create!(
      user: @admin_user,
      player: @other_player,
      season_type: "weekly",
      category: "target",
    )

    sign_in @prophet_user
    get edit_prediction_url(other_user_prediction)
    assert_redirected_to predictions_url
    assert_equal "You can only edit your own predictions.", flash[:alert]
  end

  test "prophet cannot update another user's prediction" do
    other_user_prediction = Prediction.create!(
      user: @admin_user,
      player: @other_player,
      season_type: "weekly",
      category: "target",
    )

    sign_in @prophet_user
    patch prediction_url(other_user_prediction), params: {
      prediction: {
        player_id: other_user_prediction.player_id,
        season_type: other_user_prediction.season_type,
        category: "avoid",
      }
    }
    assert_redirected_to predictions_url
    assert_equal "You can only edit your own predictions.", flash[:alert]
  end

  test "prophet cannot destroy another user's prediction" do
    other_user_prediction = Prediction.create!(
      user: @admin_user,
      player: @other_player,
      season_type: "weekly",
      category: "target",
    )

    sign_in @prophet_user
    assert_no_difference("Prediction.count") do
      delete prediction_url(other_user_prediction)
    end

    assert_redirected_to predictions_url
    assert_equal "You can only edit your own predictions.", flash[:alert]
  end

  # Tests for Admin users
  test "admin should get index with all predictions" do
    # Create another prediction from different user
    Prediction.create!(
      user: @admin_user,
      player: @other_player,
      season_type: "rest_of_season",
      category: "avoid"
    )

    sign_in @admin_user
    get predictions_url
    assert_response :success
    # Admin should see all predictions, not just their own
  end

  test "admin can view any prediction" do
    sign_in @admin_user
    get prediction_url(@prediction)
    assert_response :success
  end

  test "admin cannot edit prophet predictions" do
    sign_in @admin_user
    get edit_prediction_url(@prediction)
    assert_redirected_to predictions_url
    assert_equal "Admins cannot edit Prophet predictions.", flash[:alert]
  end

  test "admin cannot update prophet predictions" do
    sign_in @admin_user
    patch prediction_url(@prediction), params: {
      prediction: {
        player_id: @prediction.player_id,
        season_type: @prediction.season_type,
        category: "avoid",
      }
    }
    assert_redirected_to predictions_url
    assert_equal "Admins cannot edit Prophet predictions.", flash[:alert]
  end

  test "admin cannot destroy prophet predictions" do
    sign_in @admin_user
    assert_no_difference("Prediction.count") do
      delete prediction_url(@prediction)
    end

    assert_redirected_to predictions_url
    assert_equal "Admins cannot edit Prophet predictions.", flash[:alert]
  end

  # Tests for unauthenticated access
  test "guest should be redirected to sign in" do
    get predictions_url
    assert_redirected_to new_user_session_url
  end

  test "guest cannot create prediction" do
    assert_no_difference("Prediction.count") do
      post predictions_url, params: {
        prediction: {
          player_id: @player.id,
          season_type: "weekly",
          category: "target",
        }
      }
    end

    assert_redirected_to new_user_session_url
  end
end
