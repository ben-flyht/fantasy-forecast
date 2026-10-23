require "application_system_test_case"

class GoogleAnalyticsSystemTest < ApplicationSystemTestCase
  setup do
    @original = ENV["GOOGLE_ANALYTICS_ID"]
    ENV["GOOGLE_ANALYTICS_ID"] = "G-TEST123"
  end

  teardown do
    ENV["GOOGLE_ANALYTICS_ID"] = @original
  end

  def events(name)
    page.evaluate_script(<<~JS)
      Array.from(window.dataLayer || [])
        .filter((entry) => entry[0] === "event" && entry[1] === #{name.to_json})
        .map((entry) => entry[2] || {})
    JS
  end

  test "a full load and a Turbo visit each send one page view" do
    visit comparisons_path
    assert_equal 1, events("page_view").size

    click_link "Rankings", match: :first
    assert_current_path rankings_path
    assert_equal 2, events("page_view").size
    assert_equal "/rankings", events("page_view").last["page_path"]
  end

  test "building a comparison sends both sides" do
    salah = players(:midfielder)
    palmer = players(:midfielder_two)
    visit comparisons_path

    [ [ 0, "salah", salah ], [ 1, "palmer", palmer ] ].each do |side, typed, player|
      within "[data-comparison-builder-target=side][data-side='#{side}']" do
        find("input[data-comparison-builder-target=input]").set(typed)
        click_button player.full_name
      end
    end

    assert_current_path comparison_path(pair: "#{salah.comparison_param}-vs-#{palmer.comparison_param}")
    built = events("comparison_built").sole
    assert_equal [ salah.comparison_param, palmer.comparison_param ], built.values_at("player_a", "player_b")
    assert_empty %w[salah palmer] - events("player_search").map { |search| search["search_term"] }
  end
end
