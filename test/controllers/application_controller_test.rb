require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "the sitemap offers the coming gameweek and not the ones already played" do
    get "/sitemap.xml"

    assert_response :success
    assert_includes response.body, gameweek_position_path(gameweek: 21, position: "forwards")
    assert_not_includes response.body, gameweek_position_path(gameweek: 20, position: "forwards")
    assert_not_includes response.body, gameweek_position_path(gameweek: 22, position: "forwards")
  end

  test "the sitemap offers a season page for every position" do
    get "/sitemap.xml"

    %w[forwards midfielders defenders goalkeepers].each do |position|
      assert_includes response.body, season_position_path(position: position)
    end
  end

  test "the sitemap offers the comparisons worth crawling" do
    get "/sitemap.xml"

    assert_includes response.body, comparisons_path
    assert_includes response.body,
                    comparison_path(pair: Matchup.new(players(:midfielder), players(:midfielder_two)).slug)
  end

  test "the sitemap offers the armband" do
    get "/sitemap.xml"

    assert_includes response.body, captain_path
  end

  test "the sitemap offers a page for every player" do
    get "/sitemap.xml"

    Player.find_each do |player|
      assert_includes response.body, player_path(player)
    end
  end

  # A link in the row but not behind the button is a page a phone cannot reach, so
  # both carry every one of them.
  test "every main page is reachable in the row and behind the button" do
    get root_path

    [ rankings_path, captain_path, squad_path, comparisons_path ].each do |path|
      assert_select "nav a[href=?]:not([aria-label])", path, 2
    end
  end

  # Most people land on these from a search, with no history to go back through and
  # nothing on screen saying what the rest of the site is.
  test "every page a stranger lands on offers a way to the front page" do
    [ rankings_path, captain_path, squad_path, comparisons_path ].each do |path|
      get path

      assert_select "main a[href=?][data-turbo-frame=_top]", root_path, { text: "Back to Home" },
                    "#{path} has no working way back to the front page"
    end
  end

  test "a page reached from inside the site goes back to where it was listed" do
    get player_path(players(:midfielder))
    assert_select "main a", text: "Back to Rankings"

    get comparison_path(pair: Matchup.new(players(:midfielder), players(:midfielder_two)).slug)
    assert_select "main a", text: "Back to Comparisons"
  end

  test "the navigation says which page you are on" do
    get squad_path

    assert_select "nav a[href=?][aria-current=page]", squad_path
    assert_select "nav a[href=?][aria-current=page]", rankings_path, false
  end

  # Every one of these pages draws itself a picture for the preview, and until there
  # was a button nothing on the page said so: the card only existed for whoever
  # happened to paste the link.
  test "a page with a card of its own offers to share it" do
    pair = Matchup.new(players(:midfielder), players(:midfielder_two))

    [ rankings_path, player_path(players(:midfielder)), comparison_path(pair: pair.slug) ].each do |path|
      get path

      assert_select "button[data-controller=share]", { count: 1 }, "nothing to share on #{path}"
    end
  end

  # What is shared is the address we tell a crawler is canonical, not whatever
  # filters happened to be on when the reader pressed the button.
  test "sharing sends the canonical address, not the one in the bar" do
    get rankings_path, params: { team_id: teams(:arsenal).id }

    assert_select "button[data-share-url-value=?]", "#{ApplicationHelper::BASE_URL}/rankings"
  end

  # A ranking has an address per position and per gameweek and is still one page.
  test "a filtered ranking is still the rankings page" do
    get season_position_path(position: "midfielders")

    assert_select "nav a[href=?][aria-current=page]", rankings_path
  end
end
