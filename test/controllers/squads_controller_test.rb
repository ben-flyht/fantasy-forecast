require "test_helper"

class SquadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Squad.destroy_all
    Forecast.destroy_all
    Player.destroy_all
    Gameweek.destroy_all
    Team.destroy_all

    stub_player_images

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
    assert_select "title", /Best FPL Squad GW1/
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

  # The squad is drawn by the rankings' own row, so a player looks the same wherever
  # he is met. What differs is the left-hand column: a position, not a place.
  test "a pick stands where a ranking stands, led by his position" do
    build_squad

    get squad_path

    assert_select "td", text: "GK", count: 1
    assert_select "th", text: "Pos"
  end

  test "the reserve keeper heads the bench" do
    squad = build_squad
    squad.update!(picks: squad.picks + [
      { "player_id" => @player.id, "position" => "goalkeeper", "team_id" => @team.id,
        "cost" => 40, "expected_points" => 2.1, "starting" => false },
      { "player_id" => @player.id, "position" => "midfielder", "team_id" => @team.id,
        "cost" => 50, "expected_points" => 4.4, "starting" => false }
    ])

    assert_equal "goalkeeper", squad.bench.first["position"]
  end

  test "a squad has a share card of its own" do
    build_squad

    get squad_path(format: :png)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal [ ShareCard::WIDTH, ShareCard::SQUARE ], png_size(response.body)
  end

  test "the season squad's card is a different picture from the gameweek's" do
    build_squad
    build_squad(horizon: "season")

    get squad_path(format: :png)
    gameweek_card = response.body
    get season_squad_path(format: :png)

    assert_response :success
    assert_not_equal gameweek_card, response.body
  end

  test "the page tells a preview where to find its card" do
    build_squad

    get squad_path

    assert_select "meta[property='og:image'][content=?]", "#{ApplicationHelper::BASE_URL}/squad.png"
  end

  # There is no picture of a squad nobody has picked, and saying so is better than
  # sending back a card that has to explain itself.
  test "a week with no squad has no card and does not offer one" do
    get squad_path

    assert_select "meta[property='og:image'][content=?]", /squad\.png/, false

    get squad_path(format: :png)

    assert_response :not_found
  end

  test "an unknown horizon falls back to the coming gameweek rather than failing" do
    build_squad
    get "/squad", params: { horizon: "nonsense" }

    assert_response :success
    assert_select "title", /GW1/
  end

  # The armband was drawn as a (C) beside a name, which is an answer only if you
  # were looking at the picture.
  test "it names the captain rather than only marking him" do
    build_squad
    get squad_path

    assert_select "h2", /Who to captain/
    assert_select "a[href=?]", captain_path
    assert_select "a[href=?]", player_path(@player), text: @player.display_name
  end

  test "the questions it answers are printed and declared alike" do
    build_squad
    get squad_path

    assert_select "script[type='application/ld+json']", /FAQPage/
    assert_select "dt", /What is the best FPL squad right now\?/
    assert_select "dd", /4-4-2/
  end

  test "a week with no squad has no questions to answer about one" do
    get squad_path

    assert_response :success
    assert_select "script[type='application/ld+json']", { text: /FAQPage/, count: 0 }
  end
end
