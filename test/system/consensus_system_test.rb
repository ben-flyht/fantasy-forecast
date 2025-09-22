require "application_system_test_case"

class ConsensusSystemTest < ApplicationSystemTestCase
  setup do
    @forecaster_user = users(:one)  # Forecaster user
    @admin_user = users(:two)    # Admin user
    @player = players(:one)
    @player2 = players(:two)

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

    @gameweek3 = Gameweek.create!(
      fpl_id: 3,
      name: "Gameweek 3",
      start_time: 1.week.from_now,
      end_time: 2.weeks.from_now - 1.second,
      is_current: false,
      is_next: false,
      is_finished: false
    )
  end

  test "forecaster navigates to weekly consensus and sees aggregated data" do
    # Create multiple forecasts to show consensus
    forecaster2 = User.create!(
      email: "forecaster2@test.com",
      username: "Forecaster2",
      password: "password123",
      role: "forecaster"
    )

    # Create forecasts for gameweek 1
    Forecast.create!(user: @forecaster_user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: forecaster2, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @forecaster_user, player: @player2, category: "avoid", gameweek: @gameweek1)

    # Sign in as forecaster
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    click_link "Consensus"

    assert_selector "h1", text: "Weekly Consensus Rankings"

    # Check that we can see the consensus scores
    assert_text @player.name
    assert_text @player2.name

    # Player 1 should have positive consensus score (2 targets)
    within("tr", text: @player.name) do
      assert_text "2"  # consensus score
    end

    # Player 2 should have negative consensus score (1 avoid)
    within("tr", text: @player2.name) do
      assert_text "-1"  # consensus score
    end
  end

  test "user can filter consensus by week" do
    # Create forecasts for different weeks
    Forecast.create!(user: @forecaster_user, player: @player, category: "target", gameweek: @gameweek1)
    Forecast.create!(user: @forecaster_user, player: @player2, category: "target", gameweek: @gameweek2)

    # Sign in
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    click_link "Consensus"

    # Should default to week 5 (or first available week)
    assert_selector "select[name='week']"

    # Select week 1
    select "1", from: "week"

    # Should see player from week 1
    assert_text @player.name

    # Select week 2
    select "2", from: "week"

    # Should see player from week 2
    assert_text @player2.name
  end

  test "user can filter consensus by position" do
    # Create midfielder player
    midfielder = Player.create!(
      first_name: "Test",
      last_name: "Midfielder",
      team: "Test Team",
      position: "midfielder",
      fpl_id: 999
    )

    # Create forecasts for different positions
    Forecast.create!(user: @forecaster_user, player: @player, category: "target", gameweek: @gameweek1)  # goalkeeper
    Forecast.create!(user: @forecaster_user, player: midfielder, category: "target", gameweek: @gameweek1)

    # Sign in
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    click_link "Consensus"

    # Should see both players initially
    assert_text @player.name
    assert_text midfielder.name

    # Filter by GK position
    select "GK", from: "position"

    # Should only see goalkeeper
    assert_text @player.name
    assert_no_text midfielder.name

    # Filter by MID position
    select "MID", from: "position"

    # Should only see midfielder
    assert_text midfielder.name
    assert_no_text @player.name
  end

  test "consensus shows empty state when no forecasts exist" do
    # Don't create any forecasts

    # Sign in
    visit new_user_session_path
    fill_in "Email", with: @forecaster_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    click_link "Consensus"

    assert_text "No consensus data available"
  end

  test "admin can access consensus page" do
    # Create some forecast data
    Forecast.create!(user: @forecaster_user, player: @player, category: "target", gameweek: @gameweek1)

    # Sign in as admin
    visit new_user_session_path
    fill_in "Email", with: @admin_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    click_link "Consensus"

    assert_selector "h1", text: "Weekly Consensus Rankings"
    assert_text @player.name
  end

  test "unauthenticated user cannot access consensus" do
    visit consensus_index_path
    assert_current_path new_user_session_path
  end
end
