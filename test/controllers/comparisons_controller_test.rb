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

  test "the verdict is in the markup, not fetched afterwards" do
    get comparison_path(pair: pair)

    assert_select "p", text: /Expected points this gameweek/
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
    assert_select "p", text: /rest of the season/
    assert_includes response.body, "Palmer"
  end

  test "the hub offers the arguments worth having" do
    get comparisons_path

    assert_response :success
    assert_select "a[href=?]", comparison_path(pair: pair)
  end
end
