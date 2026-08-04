require "application_system_test_case"

# The horizon toggle used to submit the whole page, which threw the reader back
# to the top every time they compared a week against the season. Only the
# forecast panel changes with the horizon, so only that frame navigates.
class PlayerPageTest < ApplicationSystemTestCase
  setup do
    Forecast.destroy_all
    Gameweek.destroy_all
    @team = Team.create!(fpl_id: 971, name: "Test City", short_name: "TCY", code: 971)
    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 2.days.from_now, is_next: true)
    @player = Player.create!(first_name: "Test", last_name: "Keeper", short_name: "T.Keeper",
                             fpl_id: 9710, code: 9710, team: @team, position: "goalkeeper")
    Forecast.create!(player: @player, gameweek: @gameweek, rank: 1, score: 5.0, horizon: "gameweek")
    Forecast.create!(player: @player, gameweek: @gameweek, rank: 3, score: 180.0, horizon: "season")
  end

  test "switching the horizon rewrites the forecast panel without reloading the page" do
    visit player_path(@player)
    assert_text "5.0"

    # Survives a frame navigation; a full page load would wipe it. This, not a
    # scroll assertion, is what the reader actually feels: the document is never
    # replaced, so the scroll position is never reset.
    page.execute_script("document.body.dataset.marker = 'kept'")

    find("label", text: "Rest of Season").click

    assert_text "180.0"
    assert_no_text "Content missing"
    assert_equal "kept", page.evaluate_script("document.body.dataset.marker")
  end

  test "the horizon is in the URL, so the panel survives a refresh" do
    visit player_path(@player)
    find("label", text: "Rest of Season").click
    assert_text "180.0"

    visit current_url
    assert_text "180.0"
  end
end
