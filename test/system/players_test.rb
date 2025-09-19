require "application_system_test_case"

class PlayersTest < ApplicationSystemTestCase
  setup do
    @player = players(:one)
    @admin_user = users(:two)  # Admin user from fixtures
    @prophet_user = users(:one)  # Prophet user from fixtures
  end

  test "visiting the index" do
    visit players_url
    assert_selector "h1", text: "Players"
  end

  test "admin can successfully add a new player" do
    # Sign in as admin
    visit new_user_session_path
    fill_in "Email", with: @admin_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to players and create new
    visit players_url
    assert_selector "a", text: "New player"
    click_on "New player"

    # Fill in player form
    fill_in "Name", with: "System Test Player"
    fill_in "Team", with: "Manchester United"
    select "Forward", from: "Position"
    fill_in "Bye week", with: 9
    fill_in "Fpl id", with: 888

    click_on "Create Player"

    assert_text "Player was successfully created"
    assert_text "System Test Player"
    assert_text "Manchester United"
  end

  test "prophet visiting new player page gets redirected with error" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Try to visit new player page
    visit new_player_url

    # Should be redirected to players index with error
    assert_current_path players_path
    assert_text "Access denied. Admin privileges required."
  end

  test "prophet cannot see admin action buttons" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Visit players index
    visit players_url

    # Should not see New player button
    assert_no_selector "a", text: "New player"

    # Visit individual player page
    visit player_url(@player)

    # Should not see Edit or Destroy buttons
    assert_no_selector "a", text: "Edit"
    assert_no_selector "button", text: "Destroy"
  end

  test "guest cannot see admin action buttons" do
    # Visit players without signing in
    visit players_url

    # Should not see New player button
    assert_no_selector "a", text: "New player"

    # Visit individual player page
    visit player_url(@player)

    # Should not see Edit or Destroy buttons
    assert_no_selector "a", text: "Edit"
    assert_no_selector "button", text: "Destroy"
  end

  test "admin can see and use all action buttons" do
    # Sign in as admin
    visit new_user_session_path
    fill_in "Email", with: @admin_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Visit players index
    visit players_url

    # Should see New player button
    assert_selector "a", text: "New player"

    # Should see Edit and Destroy buttons for each player
    assert_selector "a", text: "Edit"
    assert_selector "button", text: "Destroy"
  end
end
