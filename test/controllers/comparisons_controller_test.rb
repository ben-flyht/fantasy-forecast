require "test_helper"

class ComparisonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @gameweek = gameweeks(:next_gw)
    Forecast.delete_all
    Forecast.create!(player: @salah, gameweek: @gameweek, score: 5.4, rank: 1)
    Forecast.create!(player: @palmer, gameweek: @gameweek, score: 3.9, rank: 2)
  end

  def pair
    Comparison.new(@salah, @palmer).slug
  end

  test "the page answers the question it is named after" do
    get comparison_path(pair: pair)

    assert_response :success
    assert_select "h1", text: "Mohamed Salah or Cole Palmer?"
    assert_includes response.body, "Salah"
    assert_includes response.body, "Our pick"
  end

  # The cards carry the answer: both players, the points we expect from each, and a
  # badge on the one we would have. No panel of prose repeating them.
  test "the verdict is in the markup, not fetched afterwards" do
    get comparison_path(pair: pair)

    assert_select "[data-comparison-card]", count: 2
    assert_select "[data-comparison-card][data-pick=true]", count: 1
    assert_select "[data-comparison-card][data-pick=true]", text: /Salah/
    assert_select "[data-comparison-card][data-pick=true]", text: /5\.4/
  end

  test "both orders are the same argument, and one of them is the page" do
    get comparison_path(pair: "#{@palmer.to_param}-vs-#{@salah.to_param}")

    assert_response :moved_permanently
    assert_redirected_to comparison_path(pair: pair)
  end

  test "a player against himself is answered by his own page" do
    get comparison_path(pair: "#{@salah.to_param}-vs-#{@salah.to_param}")

    assert_response :moved_permanently
    assert_redirected_to player_path(@salah)
  end

  test "a pair naming somebody who does not exist is not found" do
    get comparison_path(pair: "#{@salah.to_param}-vs-nobody-99999")

    assert_response :not_found
  end

  test "the page is its own canonical" do
    get comparison_path(pair: pair)

    assert_select "link[rel=canonical][href=?]", "#{ApplicationHelper::BASE_URL}/compare/#{pair}"
  end

  test "the link previews as a card of its own" do
    get comparison_path(pair: pair)

    assert_select "meta[property='og:image'][content=?]",
                  "#{ApplicationHelper::BASE_URL}/compare/#{pair}.png"
  end

  test "the card is a png of the size every social site asks for" do
    get comparison_path(pair: pair, format: :png)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal [ ShareCard::WIDTH, ShareCard::HEIGHT ], png_size(response.body)
  end

  test "the season horizon has its own answer" do
    Forecast.create!(player: @salah, gameweek: @gameweek, score: 40.0, rank: 1, horizon: "season")
    Forecast.create!(player: @palmer, gameweek: @gameweek, score: 60.0, rank: 2, horizon: "season")

    get comparison_path(pair: pair, horizon: "season")

    assert_response :success
    assert_select "[aria-label='Forecast horizon'] a[aria-current=page][aria-label='Rest of Season']"
    assert_select "[data-comparison-card][data-pick=true]", text: /Palmer/
  end

  test "the hub offers the arguments worth having" do
    get comparisons_path

    assert_response :success
    assert_select "a[href=?]", comparison_path(pair: pair)
  end

  # "Him or him?" is the better line, but nobody types it into a search box, so it
  # keeps its place underneath a heading that says what the page is.
  # Every pair in the game has an address; the listed ones are never the pair
  # somebody actually arrived holding.
  test "the hub offers a way to build any pair" do
    get comparisons_path

    assert_select "[data-controller=comparison-builder]"
    assert_select "input[data-comparison-builder-target=input]", count: 2
    assert_select "button[data-comparison-builder-target=submit][disabled]"
  end

  test "the search says who you might mean" do
    get comparison_search_path(q: "salah")

    assert_response :success
    assert_equal "application/json", response.media_type

    found = JSON.parse(response.body)
    assert_includes found.map { |p| p["param"] }, @salah.to_param
    assert_equal @salah.full_name, found.first["full_name"]
  end

  test "the search leaves out a player already picked" do
    get comparison_search_path(q: "salah", exclude: [ @salah.to_param ])

    assert_not_includes JSON.parse(response.body).map { |p| p["param"] }, @salah.to_param
  end

  test "the search with nothing typed says nobody rather than everybody" do
    get comparison_search_path(q: "")

    assert_empty JSON.parse(response.body)
  end

  # "search" has no "-vs-" in it, so the pair route refuses it and it reaches the
  # action it was meant for.
  test "the search address is not mistaken for a pair" do
    assert_routing "/compare/search", controller: "comparisons", action: "search"
  end

  test "the hub says what it is above the line worth reading" do
    get comparisons_path

    assert_select "h1", /FPL Player Comparisons/
    assert_select "p", text: "Him or him?"
  end

  test "the questions the hub answers are printed and declared alike" do
    get comparisons_path

    assert_select "script[type='application/ld+json']", /FAQPage/
    assert_select "dt", /Which FPL player should I pick\?/
  end
end
