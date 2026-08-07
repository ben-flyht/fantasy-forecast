require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "the front page shows the best players, whatever they play" do
    get root_path

    assert_response :success
    assert_select "h1", /FPL Rankings and Predictions/
    assert_select "table tbody tr", minimum: 1
    assert_includes response.body, players(:midfielder).display_name
  end

  # A rank is a player's place within his own position, so ordering by rank would
  # put four number ones at the top and nobody else.
  test "the best players are ordered by score, not by their place in a position" do
    get root_path

    scores = assigns_shortlist.map { |ranking| ranking.score.to_f }

    assert_equal scores.sort.reverse, scores
  end

  test "a player with no score is not one of the best players" do
    get root_path

    assert_not_includes assigns_shortlist.map(&:player_id), players(:injured_player).id
  end

  # The rankings used to live here. A link written before they moved should still land
  # on what it asked for rather than on a page that ignores it.
  test "a link carrying the rankings' own filters is sent after them" do
    get root_path, params: { position: "midfielder" }

    assert_response :moved_permanently
    assert_redirected_to rankings_path(position: "midfielder")
  end

  test "an old filtered link ends up at the address that filter lives at" do
    get root_path, params: { gameweek: 21, position: "midfielder" }
    follow_redirect!

    assert_redirected_to gameweek_position_path(gameweek: 21, position: "midfielders")
  end

  # A tracking parameter is not a filter. Bouncing every shared link through a redirect
  # would be worse than the problem this solves.
  test "a link with tracking on it is left alone" do
    get root_path, params: { utm_source: "twitter", fbclid: "abc123" }

    assert_response :success
    assert_select "h1"
  end

  test "the front page stands for itself" do
    get root_path

    assert_select "link[rel=canonical][href=?]", ApplicationHelper::BASE_URL
  end

  test "it leads to each of the four things the site does" do
    get root_path

    assert_select "main a[href=?]", rankings_path
    assert_select "main a[href=?]", captain_path
    assert_select "main a[href=?]", squad_path
    assert_select "main a[href=?]", comparisons_path
  end

  # The position pages already rank. What they were missing was anything on this
  # site pointing at them in the words people search for them in.
  test "it names each position page in the words somebody would search for it" do
    get root_path

    %w[goalkeepers defenders midfielders forwards].each do |position|
      assert_select "a[href=?]", gameweek_position_path(gameweek: gameweeks(:next_gw).fpl_id, position: position),
                    text: "Best FPL #{position} this week"
    end
  end

  # The armband is the question most managers arrive with, and the top of the list
  # is already the answer.
  test "it names the captain pick and sends you to the page that argues it" do
    get root_path

    assert_select "h2", /Who to captain/
    assert_select "main a[href=?]", captain_path
    assert_select "p", /#{players(:midfielder).display_name}/
  end

  # A schema claiming an answer the reader cannot see is the one thing Google
  # treats as a lie, so the questions are printed as well as declared.
  test "the questions it answers are printed and declared alike" do
    get root_path

    assert_select "script[type='application/ld+json']", /FAQPage/
    assert_select "dt", /Who are the best FPL players this week\?/
    assert_select "dd", /#{players(:midfielder).display_name}/
  end

  # The front page is the one a stranger shares, so its preview is the squad rather
  # than the site icon.
  test "the squad card is the front page's picture, when there is a squad" do
    build_squad

    get root_path

    assert_select "meta[property='og:image'][content=?]", "#{ApplicationHelper::BASE_URL}/squad.png"
    assert_select "main img[src=?]", "/squad.png"
    assert_select "button[data-controller=share][data-share-url-value=?]",
                  "#{ApplicationHelper::BASE_URL}/squad"
  end

  test "no squad yet is a quiet front page, not a broken one" do
    get root_path

    assert_response :success
    assert_select "meta[property='og:image'][content=?]", /squad\.png/, false
    assert_select "p", /No squad has been picked/
  end

  private

  def assigns_shortlist
    @controller.view_assigns["shortlist"]
  end

  def build_squad
    Squad.create!(gameweek: gameweeks(:next_gw), horizon: "gameweek", formation: "4-4-2",
                  cost: 985, expected_points: 58.25,
                  picks: [ { "player_id" => players(:midfielder).id, "position" => "midfielder",
                             "team_id" => players(:midfielder).team_id, "cost" => 55,
                             "expected_points" => 5.1, "starting" => true } ])
  end
end
