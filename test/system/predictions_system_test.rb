require "application_system_test_case"

class PredictionsSystemTest < ApplicationSystemTestCase
  setup do
    @prophet_user = users(:one)  # Prophet user
    @admin_user = users(:two)    # Admin user
    @player = players(:one)
    @player2 = players(:two)

    # Clear predictions to avoid conflicts
    Prediction.destroy_all
  end

  test "prophet logs in, creates a new weekly prediction and sees it on dashboard" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions
    click_link "Predictions"
    assert_selector "h1", text: "My Predictions"

    # Should show empty state initially
    assert_text "No predictions yet"

    # Add a new weekly prediction
    click_link "New prediction"

    select "#{@player.name} (#{@player.team} - #{@player.position})", from: "Player"
    select "Weekly Prediction", from: "Season type"
    fill_in "Week", with: "3"
    select "Must Have", from: "Category"

    click_button "Create Prediction"

    assert_text "Prediction was successfully created"

    # Go back to index and verify it's listed
    click_link "Predictions"
    assert_text @player.name
    assert_text "Must Have"
    assert_text "Week 3"

    # Should see grouped display
    within(".bg-green-50") do  # Must Have section
      assert_text @player.name
      assert_text "Week 3"
    end
  end

  test "prophet creates rest of season prediction and sees it grouped correctly" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions and add new prediction
    click_link "Predictions"
    click_link "New prediction"

    select "#{@player2.name} (#{@player2.team} - #{@player2.position})", from: "Player"
    select "Rest of Season", from: "Season type"
    select "Better Than Expected", from: "Category"

    click_button "Create Prediction"

    assert_text "Prediction was successfully created"

    # Go back to index and verify grouping
    click_link "Predictions"

    # Should see grouped display in Better Than Expected section
    within(".bg-blue-50") do  # Better Than Expected section
      assert_text @player2.name
      assert_text "Rest of Season"
    end
  end

  test "creating a duplicate prediction triggers validation error" do
    # Create existing prediction
    existing_prediction = Prediction.create!(
      user: @prophet_user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions and try to create duplicate
    click_link "Predictions"
    click_link "New prediction"

    # Try to create duplicate prediction (same player, week, season_type)
    select "#{@player.name} (#{@player.team} - #{@player.position})", from: "Player"
    select "Weekly Prediction", from: "Season type"
    fill_in "Week", with: "1"  # Same week as existing prediction
    select "Better Than Expected", from: "Category"  # Different category but still duplicate

    click_button "Create Prediction"

    # Should see validation error
    assert_text "User has already been taken"
    assert_selector "#error_explanation"
  end

  test "prophet can edit and update their prediction" do
    # Create existing prediction
    prediction = Prediction.create!(
      user: @prophet_user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 2
    )

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions and edit
    click_link "Predictions"

    # Find and click edit link
    within(".bg-green-50") do  # Must Have section
      click_link "Edit"
    end

    # Update the category
    select "Worse Than Expected", from: "Category"
    click_button "Update Prediction"

    assert_text "Prediction was successfully updated"

    # Verify the change - should now be in Worse Than Expected section
    click_link "Predictions"
    within(".bg-red-50") do  # Worse Than Expected section
      assert_text @player.name
      assert_text "Week 2"
    end

    # Should not be in Must Have section anymore
    assert_no_selector ".bg-green-50", text: @player.name
  end

  test "prophet can delete their prediction" do
    # Create existing prediction
    prediction = Prediction.create!(
      user: @prophet_user,
      player: @player,
      season_type: "rest_of_season",
      category: "better_than_expected"
    )

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions and delete
    click_link "Predictions"

    # Find and click delete link
    within(".bg-blue-50") do  # Better Than Expected section
      accept_confirm do
        click_link "Delete"
      end
    end

    assert_text "Prediction was successfully destroyed"

    # Should show empty state again
    assert_text "No predictions yet"
  end

  test "index shows grouping by category with multiple predictions" do
    # Create multiple predictions
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "must_have", week: 1)
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "weekly", category: "must_have", week: 2)
    Prediction.create!(user: @prophet_user, player: players(:one), season_type: "rest_of_season", category: "better_than_expected")

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to predictions
    click_link "Predictions"

    # Should see Must Have section with 2 predictions
    within(".bg-green-50") do  # Must Have section
      assert_text "Must Have"
      assert_text @player.name
      assert_text @player2.name
      assert_text "Week 1"
      assert_text "Week 2"
    end

    # Should see Better Than Expected section with 1 prediction
    within(".bg-blue-50") do  # Better Than Expected section
      assert_text "Better Than Expected"
      assert_text "Rest of Season"
    end

    # Should not see Worse Than Expected section since no predictions
    assert_no_selector ".bg-red-50"
  end

  test "admin can view all predictions but cannot edit prophet ones" do
    # Create predictions from prophet user
    prophet_prediction = Prediction.create!(
      user: @prophet_user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
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

    # Should not see "New prediction" button (admins can't create)
    assert_no_link "New prediction"

    # Should only see "View" links, not "Edit" or "Delete"
    within(".bg-green-50") do  # Must Have section
      assert_link "View"
      assert_no_link "Edit"
      assert_no_link "Delete"
    end
  end

  test "week field shows and hides based on season type selection" do
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

  test "guest user is redirected to sign in" do
    # Try to access predictions without signing in
    visit predictions_path

    # Should be redirected to sign in page
    assert_current_path new_user_session_path
    assert_text "You need to sign in or sign up before continuing"
  end

  test "prophet cannot access another user's prediction edit page" do
    # Create prediction from admin user
    admin_prediction = Prediction.create!(
      user: @admin_user,
      player: @player,
      season_type: "weekly",
      category: "must_have",
      week: 1
    )

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Try to directly access edit page for admin's prediction
    visit edit_prediction_path(admin_prediction)

    # Should be redirected to predictions index with error message
    assert_current_path predictions_path
    assert_text "You can only edit your own predictions"
  end
end
