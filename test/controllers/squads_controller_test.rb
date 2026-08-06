require "test_helper"

class SquadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Squad.destroy_all
    Forecast.destroy_all
    Player.destroy_all
    Gameweek.destroy_all
    Team.destroy_all

    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 3.days.from_now, is_next: true)
    @team = Team.create!(fpl_id: 970, code: 970, name: "Test City", short_name: "TCY")
    @player = Player.create!(first_name: "Test", last_name: "Keeper", short_name: "T.Keeper",
                             fpl_id: 9700, code: 9700, team: @team, position: "goalkeeper")
  end

  def build_squad(horizon: "gameweek")
    Squad.create!(gameweek: @gameweek, horizon: horizon, formation: "4-4-2",
                  cost: 985, expected_points: 58.25,
                  picks: [ { "player_id" => @player.id, "position" => "goalkeeper",
                             "team_id" => @team.id, "cost" => 55,
                             "expected_points" => 5.1, "starting" => true } ])
  end

  test "it shows the squad written for the coming gameweek" do
    build_squad
    get squad_path

    assert_response :success
    assert_select "h1", /Best .* Squad/
    assert_select "title", /Best FPL Team GW1/
  end

  test "the season squad is its own page" do
    build_squad(horizon: "season")
    get season_squad_path

    assert_response :success
    assert_select "title", /Rest of Season/
  end

  # Pre-season, and for a few minutes after a new gameweek turns over, there is no
  # squad yet. That is a quiet page, not an error.
  test "it says so plainly when no squad has been written" do
    get squad_path

    assert_response :success
    assert_select "h2", /No squad yet/
  end

  test "an unknown horizon falls back to the coming gameweek rather than failing" do
    build_squad
    get "/squad", params: { horizon: "nonsense" }

    assert_response :success
    assert_select "title", /GW1/
  end
end
