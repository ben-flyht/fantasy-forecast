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
    Forecast.create!(player: @player, gameweek: @gameweek, rank: 1, score: 5.0, horizon: "gameweek",
                     working: weekly_working)
    Forecast.create!(player: @player, gameweek: @gameweek, rank: 3, score: 180.0, horizon: "season",
                     working: season_working)
  end

  def weekly_working
    { "ours" => 4.2, "crowd" => 3.5, "perf_factor" => 1.2, "per_90" => 4.6, "minutes" => 82,
      "form" => 1.0, "games" => 1.04, "transfers" => 1.0,
      "opponents" => [ { "name" => "Test Rovers", "home" => true, "difficulty" => 2 } ] }
  end

  def season_working
    { "ours" => 4.2, "crowd" => 3.5, "perf_factor" => 1.2, "per_90" => 4.6, "minutes" => 82,
      "form" => 1.0, "games" => 38.4, "transfers" => 1.0,
      "opponents" => Array.new(38) { { "name" => "Test Rovers", "home" => true, "difficulty" => 3 } } }
  end

  test "switching the horizon rewrites the forecast without reloading the page" do
    visit player_path(@player)
    assert_text "5.0"

    # The toggle lives in the heading now, above the panel it changes, so the whole
    # page navigates rather than one frame. What still has to hold is that Turbo
    # drives it: a window survives a Turbo visit and does not survive a browser
    # reload, so this is the difference the reader actually feels.
    page.execute_script("window.marker = 'kept'")

    click_link "Rest of Season"

    assert_text "180.0"
    assert_no_text "Content missing"
    assert_equal "kept", page.evaluate_script("window.marker"),
                 "the browser reloaded rather than Turbo swapping the body"
  end

  test "the horizon is in the URL, so the panel survives a refresh" do
    visit player_path(@player)
    click_link "Rest of Season"
    assert_text "180.0"

    visit current_url
    assert_text "180.0"
  end

  # The number is only worth acting on if the page says where it came from. All of
  # this is stored on the forecast already; showing it is the whole point.
  test "the panel shows the arithmetic the forecast was built from" do
    visit player_path(@player)

    assert_text "HOW WE GOT THERE", exact: false
    assert_text "Worth 4.20 points a game", exact: false
    assert_text "What his record says"
    assert_text "Test Rovers"
    assert_text "+20%", exact: false
  end

  test "the working follows the horizon, so a season reads as a season" do
    visit player_path(@player)
    assert_text "Test Rovers (home)"

    click_link "Rest of Season"

    assert_text "38 fixtures to come", exact: false
    assert_no_text "Content missing"
  end

  # A rate that is simply the answer again, printed twice, reads as a fault. It
  # happens honestly: a player who plays the full ninety is worth per 90 exactly
  # what he is worth a game.
  test "a figure that would only repeat itself is not printed twice" do
    Forecast.find_by(player: @player, horizon: "gameweek")
            .update!(working: weekly_working.merge("crowd" => 4.2, "perf_factor" => nil,
                                                   "per_90" => 4.2, "minutes" => 90))

    visit player_path(@player)

    assert_text "His record and his price say the same thing", exact: false
    assert_text "He is expected to play the full 90 minutes"
    assert_no_text "What his record says"
  end

  test "a forecast with no working behind it simply says nothing" do
    Forecast.find_by(player: @player, horizon: "gameweek").update!(working: {})

    visit player_path(@player)

    assert_text "5.0", exact: false
    assert_no_text "HOW WE GOT THERE"
  end

  # A man ruled out is forecast nought, but the working still says what he would
  # be worth fit. Without a word of explanation the panel contradicts its own
  # headline, and the reader is entitled to think one of them is broken.
  test "a forecast cut to nought by fitness says so" do
    Statistic.create!(player: @player, gameweek: @gameweek, type: "chance_of_playing", value: 0)

    visit player_path(@player)

    assert_text "not expected to play at all this gameweek", exact: false
  end

  test "a goalkeeper is told his club has one place to share out" do
    visit player_path(@player)

    assert_text "share of his club's one goalkeeping place", exact: false
  end
end
