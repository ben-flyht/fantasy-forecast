require "application_system_test_case"

class ForecastsSystemTest < ApplicationSystemTestCase
  setup do
    @forecaster_user = users(:one)  # Forecaster user
    @admin_user = users(:two)    # Admin user
    @player = players(:one)
    @player2 = players(:two)

    # Clear data to avoid conflicts
    Forecast.destroy_all
    Gameweek.destroy_all

    # Create gameweeks for testing
    @current_gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: 1.week.ago,
      end_time: Time.current - 1.second,
      is_current: true,
      is_next: false,
      is_finished: false
    )

    @next_gameweek = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current,
      end_time: 1.week.from_now - 1.second,
      is_current: false,
      is_next: true,
      is_finished: false
    )
  end

  test "forecaster logs in, creates a new forecast and sees it on dashboard" do
    # Sign in as forecaster
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to forecasts
    click_link "Forecasts"
    assert_selector "h1", text: "My Forecasts"

    # Should show empty state initially
    assert_text "No forecasts yet"

    # Add a new forecast
    click_link "New forecast"

    select "#{@player.name} (#{@player.team} - #{@player.position})", from: "Player"
    select "Target", from: "Category"

    click_button "Create Forecast"

    assert_text "Forecast was successfully created"

    # Go back to index and verify it's listed
    click_link "Forecasts"
    assert_text @player.name
    assert_text "Target"
    assert_text @next_gameweek.name

    # Should see grouped display
    within(".bg-green-50") do  # Target section
      assert_text @player.name
      assert_text @next_gameweek.name
    end
  end

  test "creating a duplicate forecast triggers validation error" do
    # Create existing forecast
    existing_forecast = Forecast.create!(
      user: @forecaster_user,
      player: @player,
      category: "target",
      gameweek: @next_gameweek
    )

    # Sign in as forecaster
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to forecasts and try to create duplicate
    click_link "Forecasts"
    click_link "New forecast"

    # Try to create duplicate forecast (same player, gameweek)
    select "#{@player.name} (#{@player.team} - #{@player.position})", from: "Player"
    select "Avoid", from: "Category"  # Different category but still duplicate

    click_button "Create Forecast"

    # Should see validation error
    assert_text "User has already been taken"
    assert_selector "#error_explanation"
  end

  test "forecaster can edit and update their forecast" do
    # Create existing forecast
    forecast = Forecast.create!(
      user: @forecaster_user,
      player: @player,
      category: "target",
      gameweek: @current_gameweek
    )

    # Sign in as forecaster
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to forecasts and edit
    click_link "Forecasts"

    # Find and click edit link
    within(".bg-green-50") do  # Target section
      click_link "Edit"
    end

    # Update the category
    select "Avoid", from: "Category"
    click_button "Update Forecast"

    assert_text "Forecast was successfully updated"

    # Verify the change - should now be in Avoid section
    click_link "Forecasts"
    within(".bg-red-50") do  # Avoid section
      assert_text @player.name
      assert_text @current_gameweek.name
    end

    # Should not be in Target section anymore
    assert_no_selector ".bg-green-50", text: @player.name
  end

  test "forecaster can delete their forecast" do
    # Create existing forecast
    forecast = Forecast.create!(
      user: @forecaster_user,
      player: @player,
      category: "avoid",
      gameweek: @next_gameweek
    )

    # Sign in as forecaster
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to forecasts and delete
    click_link "Forecasts"

    # Find and click delete link
    within(".bg-red-50") do  # Avoid section
      accept_confirm do
        click_link "Delete"
      end
    end

    assert_text "Forecast was successfully destroyed"

    # Verify it's gone
    assert_text "No forecasts yet"
  end

  test "admin can view all forecasts but cannot edit forecaster's forecast" do
    # Create forecast as forecaster user
    forecast = Forecast.create!(
      user: @forecaster_user,
      player: @player,
      category: "target",
      gameweek: @next_gameweek
    )

    # Sign in as admin
    visit new_user_session_path
    fill_in "Email", with: @admin_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to forecasts
    click_link "Forecasts"

    # Admin should see all forecasts
    assert_text @player.name
    assert_text "Target"

    # Try to edit - should be redirected
    within(".bg-green-50") do
      click_link "Edit"
    end

    assert_text "Admins cannot edit forecaster forecasts"
    assert_current_path forecasts_path
  end

  test "unauthenticated user cannot access forecasts" do
    visit forecasts_path
    assert_current_path new_user_session_path
  end
end