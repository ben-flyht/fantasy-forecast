require "application_system_test_case"

class ConsensusSystemTest < ApplicationSystemTestCase
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

  test "prophet navigates to weekly consensus and sees aggregated data" do
    # Create multiple predictions to show consensus
    prophet2 = User.create!(
      email: "prophet2@test.com",
      username: "Prophet2",
      password: "password123",
      password_confirmation: "password123",
      role: "prophet"
    )

    # Create predictions showing consensus for gameweek 1
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: prophet2, player: @player, season_type: "weekly", category: "must_have", gameweek: @gameweek1)
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "weekly", category: "better_than_expected", gameweek: @gameweek1)

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    click_link "Consensus"

    # Should be on weekly consensus page
    assert_current_path consensus_weekly_path
    assert_text "Weekly Consensus"
    assert_text @gameweek1.name

    # Should see consensus data grouped by category
    within(".bg-green-600", text: "Must Have") do
      assert_text "Must Have"
    end

    # Should see player with multiple votes
    within(".bg-green-50") do
      assert_text @player.name
      assert_text @player.team
      assert_text @player.position
      assert_text "2"  # Vote count
      assert_text "2 votes"
    end

    # Should see better than expected section
    within(".bg-blue-600", text: "Better Than Expected") do
      assert_text "Better Than Expected"
    end

    within(".bg-blue-50") do
      assert_text @player2.name
      assert_text "1"  # Vote count
      assert_text "1 vote"
    end

    # Should see worse than expected section (empty)
    within(".bg-red-600", text: "Worse Than Expected") do
      assert_text "Worse Than Expected"
    end

    assert_text "No predictions in this category yet"
  end

  test "prophet selects different week and sees updated data" do
    # Create predictions for different weeks
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "must_have")
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "weekly", category: "must_have")

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    visit consensus_weekly_path

    # Should show Week 1 by default with @player
    assert_text "Week 1"
    assert_text @player.name

    # Select Week 3 from dropdown
    select "3", from: "Week:"

    # Page should update to show Week 3 data
    assert_text "Week 3"
    assert_text @player2.name
    assert_no_text @player.name  # Should not show Week 1 player anymore
  end

  test "prophet navigates to rest of season consensus" do
    # Create rest of season predictions
    prophet2 = User.create!(
      email: "prophet2@test.com",
      username: "Prophet2",
      password: "password123",
      password_confirmation: "password123",
      role: "prophet"
    )

    Prediction.create!(user: @prophet_user, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: prophet2, player: @player, season_type: "rest_of_season", category: "must_have")
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "rest_of_season", category: "worse_than_expected")

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to weekly consensus first
    visit consensus_weekly_path

    # Click to go to rest of season
    click_link "View Rest of Season Consensus"

    # Should be on rest of season consensus page
    assert_current_path consensus_rest_of_season_path
    assert_text "Rest of Season Consensus"
    assert_text "Long-term predictions for the remainder of the fantasy season"

    # Should see must have section with @player (2 votes)
    within(".bg-green-50") do
      assert_text @player.name
      assert_text @player.team
      assert_text @player.position
      assert_text "2"  # Vote count
      assert_text "2 votes"
      assert_text @player.short_name if @player.short_name
    end

    # Should see worse than expected section with @player2
    within(".bg-red-50") do
      assert_text @player2.name
      assert_text "1"  # Vote count
      assert_text "1 vote"
    end

    # Should see statistics section
    assert_text "Consensus Statistics"
    assert_text "1"  # Must Have Players count
    assert_text "0"  # Better Than Expected count
    assert_text "1"  # Worse Than Expected count
  end

  test "prophet sees empty state when no predictions exist" do
    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to weekly consensus
    visit consensus_weekly_path

    # Should see empty state
    assert_text "No Consensus Data"
    assert_text "There are no predictions for Week 1 yet"
    assert_link "View Rest of Season Consensus"

    # Navigate to rest of season consensus
    visit consensus_rest_of_season_path

    # Should see empty state
    assert_text "No Season Consensus Data"
    assert_text "There are no rest of season predictions yet"
    assert_link "View Weekly Consensus"
    assert_link "Make a Prediction"
  end

  test "prophet can navigate between weekly and rest of season views" do
    # Create predictions for both types
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "must_have")
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "rest_of_season", category: "must_have")

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Start at weekly consensus
    visit consensus_weekly_path
    assert_text "Weekly Consensus"
    assert_text @player.name

    # Navigate to rest of season
    click_link "View Rest of Season Consensus"
    assert_current_path consensus_rest_of_season_path
    assert_text "Rest of Season Consensus"
    assert_text @player2.name

    # Navigate back to weekly
    click_link "Weekly Consensus"
    assert_current_path consensus_weekly_path
    assert_text "Weekly Consensus"
    assert_text @player.name
  end

  test "admin can view consensus but sees all user predictions" do
    # Create predictions from different users
    prophet2 = User.create!(
      email: "prophet2@test.com",
      username: "Prophet2",
      password: "password123",
      password_confirmation: "password123",
      role: "prophet"
    )

    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "must_have")
    Prediction.create!(user: prophet2, player: @player, season_type: "weekly", category: "must_have")

    # Sign in as admin
    visit new_user_session_path
    fill_in "Email", with: @admin_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    click_link "Consensus"

    # Should see aggregated data from all prophets
    assert_text "Weekly Consensus"
    within(".bg-green-50") do
      assert_text @player.name
      assert_text "2"  # Should show combined votes from both prophets
      assert_text "2 votes"
    end
  end

  test "consensus shows players ranked by vote count" do
    # Create predictions with different vote counts
    prophet2 = User.create!(
      email: "prophet2@test.com",
      username: "Prophet2",
      password: "password123",
      password_confirmation: "password123",
      role: "prophet"
    )

    prophet3 = User.create!(
      email: "prophet3@test.com",
      username: "Prophet3",
      password: "password123",
      password_confirmation: "password123",
      role: "prophet"
    )

    # @player gets 3 votes, @player2 gets 1 vote
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "must_have")
    Prediction.create!(user: prophet2, player: @player, season_type: "weekly", category: "must_have")
    Prediction.create!(user: prophet3, player: @player, season_type: "weekly", category: "must_have")
    Prediction.create!(user: @prophet_user, player: @player2, season_type: "weekly", category: "must_have")

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Navigate to consensus
    visit consensus_weekly_path

    # Find all must have players and check ranking
    must_have_section = find(".bg-white", text: "Must Have")
    player_cards = must_have_section.all(".bg-green-50")

    # First player should be @player with 3 votes (rank 1)
    within(player_cards[0]) do
      assert_text "1"  # Rank number
      assert_text @player.name
      assert_text "3"  # Vote count
    end

    # Second player should be @player2 with 1 vote (rank 2)
    within(player_cards[1]) do
      assert_text "2"  # Rank number
      assert_text @player2.name
      assert_text "1"  # Vote count
    end
  end

  test "guest user is redirected to sign in when accessing consensus" do
    # Try to access weekly consensus without signing in
    visit consensus_weekly_path
    assert_current_path new_user_session_path
    assert_text "You need to sign in or sign up before continuing"

    # Try to access rest of season consensus without signing in
    visit consensus_rest_of_season_path
    assert_current_path new_user_session_path
    assert_text "You need to sign in or sign up before continuing"
  end

  test "consensus pages are responsive and display properly on different screen sizes" do
    # Create test data
    Prediction.create!(user: @prophet_user, player: @player, season_type: "weekly", category: "must_have")

    # Sign in as prophet
    visit new_user_session_path
    fill_in "Email", with: @prophet_user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    # Test weekly consensus page
    visit consensus_weekly_path

    # Should have responsive grid classes
    assert_selector ".grid.grid-cols-1.lg\\:grid-cols-3"

    # Cards should be properly styled
    assert_selector ".bg-white.shadow.rounded-lg"

    # Should have mobile-friendly navigation
    assert_selector ".flex.flex-col.sm\\:flex-row"
  end
end
