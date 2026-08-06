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
                    comparison_path(pair: Comparison.new(players(:midfielder), players(:midfielder_two)).slug)
  end

  test "the sitemap offers a page for every player" do
    get "/sitemap.xml"

    Player.find_each do |player|
      assert_includes response.body, player_path(player)
    end
  end
end
