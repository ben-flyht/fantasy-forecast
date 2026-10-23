require "application_system_test_case"

# The horizon and the positions are links inside a Turbo frame. That makes them the
# one part of the rankings page no controller test can reach: when the season was
# renamed, the control kept sending managers to a route that no longer existed, every
# request returned a 404, and Turbo wrote "Content missing" into the frame. Everything
# else was green.
class RankingsTest < ApplicationSystemTestCase
  setup do
    Forecast.destroy_all
    Gameweek.destroy_all
    @team = Team.create!(fpl_id: 970, name: "Test City", short_name: "TCY", code: 970)
    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 2.days.from_now, is_next: true)
    @player = Player.create!(first_name: "Test", last_name: "Defender", short_name: "T.Defender",
                             fpl_id: 9700, code: 9700, team: @team, position: "defender")
    Forecast.create!(player: @player, gameweek: @gameweek, rank: 1, score: 5.0, horizon: "gameweek")
    Forecast.create!(player: @player, gameweek: @gameweek, rank: 1, score: 180.0, horizon: "season")
  end

  {
    "the coming week" => -> { gameweek_position_path(gameweek: 1, position: "defenders") },
    "the next five" => -> { upcoming_position_path(position: "defenders") },
    "the season" => -> { season_position_path(position: "defenders") }
  }.each do |name, path|
    test "the price slider filters #{name}" do
      pricey = Player.create!(first_name: "Pricey", last_name: "Defender", short_name: "P.Defender",
                              fpl_id: 9702, code: 9702, team: @team, position: "defender")
      Forecast.create!(player: @player, gameweek: @gameweek, rank: 1, score: 5.0, horizon: "upcoming")
      Horizon::KEYS.each do |horizon|
        Forecast.create!(player: pricey, gameweek: @gameweek, rank: 2, score: 4.0, horizon: horizon)
      end
      Statistic.create!(player: @player, gameweek: @gameweek, type: "now_cost", value: 45)
      Statistic.create!(player: pricey, gameweek: @gameweek, type: "now_cost", value: 70)
      start = instance_exec(&path)

      visit start
      assert_selector player_row(pricey)
      move_slider("max_price", "5.0")

      assert_no_text "Content missing"
      assert_no_selector player_row(pricey)
      assert_selector player_row(@player)
      assert_current_path "#{start}?max_price=5"
    end
  end

  test "switching the horizon to the season shows the season's rankings" do
    visit gameweek_position_path(gameweek: 1, position: "defenders")
    assert_text @player.short_name

    click_link "Rest of Season"

    # The frame should hold rankings, not Turbo's missing-content notice.
    assert_no_text "Content missing"
    assert_text @player.short_name
    assert_current_path season_position_path(position: "defenders")
  end

  test "switching back to the coming week shows that week's rankings" do
    visit season_position_path(position: "defenders")

    click_link "Gameweek 1"

    assert_text @player.short_name
    assert_no_text "Content missing"
    assert_current_path gameweek_position_path(gameweek: 1, position: "defenders")
  end

  # A frame swap rewrites the frame and pushes a new URL, but leaves the title alone,
  # so the tab and the browser history can end up naming a page nobody is looking at.
  test "the browser title follows the horizon" do
    visit gameweek_position_path(gameweek: 1, position: "defenders")
    assert_title "Best FPL Defenders GW1 | Fantasy Forecast"

    click_link "Rest of Season"

    assert_current_path season_position_path(position: "defenders")
    assert_title "Best FPL Defenders Rest of Season | Fantasy Forecast"
  end

  test "the browser title follows the position" do
    midfielder = Player.create!(first_name: "Test", last_name: "Midfielder", short_name: "T.Midfielder",
                                fpl_id: 9701, code: 9701, team: @team, position: "midfielder")
    Forecast.create!(player: midfielder, gameweek: @gameweek, rank: 1, score: 4.0, horizon: "gameweek")

    visit gameweek_position_path(gameweek: 1, position: "defenders")
    assert_title "Best FPL Defenders GW1 | Fantasy Forecast"

    click_link "Midfielders"

    assert_current_path gameweek_position_path(gameweek: 1, position: "midfielders")
    assert_title "Best FPL Midfielders GW1 | Fantasy Forecast"
  end

  private

  def player_row(player)
    "[onclick*='#{player_path(player)}']"
  end

  def move_slider(name, value)
    execute_script(<<~JS, name, value)
      const input = document.querySelector(`input[name='${arguments[0]}']`)
      input.value = arguments[1]
      input.dispatchEvent(new Event("change", { bubbles: true }))
    JS
  end
end
