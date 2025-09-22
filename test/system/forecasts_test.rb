require "application_system_test_case"

class ForecastsTest < ApplicationSystemTestCase
  setup do
    @forecast = forecasts(:one)
  end

  test "visiting the index" do
    sign_in users(:one)
    visit forecasts_url
    assert_selector "h1", text: "My Forecasts"
  end

  test "should create forecast" do
    sign_in users(:one)

    # Create gameweek for testing
    Gameweek.destroy_all
    gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current,
      end_time: 1.week.from_now,
      is_next: true
    )

    visit forecasts_url
    click_on "New forecast"

    select players(:one).name, from: "Player"
    select "Target", from: "Category"

    click_on "Create Forecast"

    assert_text "Forecast was successfully created"
  end

  test "should update Forecast" do
    sign_in users(:one)

    # Ensure forecast exists with proper gameweek
    Forecast.destroy_all
    Gameweek.destroy_all

    gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current,
      end_time: 1.week.from_now,
      is_next: true
    )

    forecast = Forecast.create!(
      user: users(:one),
      player: players(:one),
      category: "target",
      gameweek: gameweek
    )

    visit forecasts_url
    click_on "Edit", match: :first

    select "Avoid", from: "Category"

    click_on "Update Forecast"

    assert_text "Forecast was successfully updated"
  end

  test "should destroy Forecast" do
    sign_in users(:one)

    # Ensure forecast exists
    Forecast.destroy_all
    Gameweek.destroy_all

    gameweek = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: Time.current,
      end_time: 1.week.from_now,
      is_next: true
    )

    Forecast.create!(
      user: users(:one),
      player: players(:one),
      category: "target",
      gameweek: gameweek
    )

    visit forecasts_url
    click_on "Delete", match: :first
    accept_confirm

    assert_text "Forecast was successfully destroyed"
  end
end
