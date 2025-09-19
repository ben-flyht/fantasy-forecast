require "application_system_test_case"

class PredictionsTest < ApplicationSystemTestCase
  setup do
    @prophet_user = users(:one)  # Prophet user
    @admin_user = users(:two)    # Admin user
    @player = players(:one)
    @other_player = players(:two)

    # Clear predictions to avoid conflicts
    Prediction.destroy_all

    @prediction = Prediction.create!(
      user: @prophet_user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )
  end

  test "prophet logs in, adds a prediction, and sees it listed" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions
    click_link "Predictions"
    assert_selector "h1", text: "My Predictions"

    # Should see existing prediction
    assert_text @player.name

    # Add a new prediction
    click_link "New prediction"

    select "#{@other_player.name} (#{@other_player.team} - #{@other_player.position})", from: "Player"
    select "Weekly Prediction", from: "Season type"
    fill_in "Week", with: "2"
    select "Better Than Expected", from: "Category"

    click_button "Create Prediction"

    assert_text "Prediction was successfully created"

    # Go back to index and verify it's listed
    click_link "Predictions"
    assert_text @other_player.name
    assert_text "Better Than Expected"
  end

  test "prophet tries to add duplicate prediction and gets validation error" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions and add new prediction
    click_link "Predictions"
    click_link "New prediction"

    # Try to create duplicate prediction (same player, week, season_type)
    select "#{@player.name} (#{@player.team} - #{@player.position})", from: "Player"
    select "Weekly Prediction", from: "Season type"
    fill_in "Week", with: "1"  # Same week as existing prediction
    select "Better Than Expected", from: "Category"

    click_button "Create Prediction"

    # Should see validation error
    assert_text "User has already been taken"
    assert_selector "#error_explanation"
  end

  test "prophet can edit their own prediction" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions and edit existing one
    click_link "Predictions"

    # Find and click edit link for the prediction
    within(".bg-gray-50") do
      click_link "Edit"
    end

    # Update the category
    select "Worse Than Expected", from: "Category"
    click_button "Update Prediction"

    assert_text "Prediction was successfully updated"

    # Verify the change
    click_link "Predictions"
    assert_text "Worse Than Expected"
  end

  test "prophet can delete their own prediction" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions and delete existing one
    click_link "Predictions"

    # Find and click delete link for the prediction
    within(".bg-gray-50") do
      accept_confirm do
        click_link "Delete"
      end
    end

    assert_text "Prediction was successfully destroyed"

    # Should show empty state
    assert_text "No predictions yet"
  end

  test "admin can view all predictions but cannot edit prophet ones" do
    # Create prediction from another user (prophet)
    other_prediction = Prediction.create!(
      user: @prophet_user,
      player: @other_player,
      season_type: "rest_of_season",
      category: "better_than_expected"
    )

    # Sign in as admin
    visit new_user_session_path
    fill_in "Email", with: @admin_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions
    click_link "Predictions"

    # Should see predictions from all users with usernames
    assert_text @prophet_user.username
    assert_text @player.name
    assert_text @other_player.name

    # Should not see "New prediction" button (admins can't create)
    assert_no_link "New prediction"

    # Should only see "View" links, not "Edit" or "Delete"
    within(".bg-gray-50") do
      assert_link "View"
      assert_no_link "Edit"
      assert_no_link "Delete"
    end
  end

  test "week field shows/hides based on season type selection" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to new prediction form
    click_link "Predictions"
    click_link "New prediction"

    # Initially week field should be hidden
    assert_no_selector "#week-field", visible: true

    # Select weekly prediction - week field should appear
    select "Weekly Prediction", from: "Season type"
    assert_selector "#week-field", visible: true

    # Select rest of season - week field should disappear
    select "Rest of Season", from: "Season type"
    assert_no_selector "#week-field", visible: true
  end
end
