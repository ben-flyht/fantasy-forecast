require "test_helper"

class TabBarComponentTest < ViewComponent::TestCase
  LINKS = [ [ "Rankings", "/rankings", false, :rankings ], [ "Squad", "/squad", true, :squad ] ].freeze

  test "every destination is a link with its name and an icon" do
    render_inline TabBarComponent.new(links: LINKS)

    assert_selector "nav[aria-label=Main] a[href='/rankings']", text: "Rankings"
    assert_selector "a[href='/squad'] svg[aria-hidden=true]"
  end

  test "the page you are on is said in the markup as well as the ink" do
    render_inline TabBarComponent.new(links: LINKS)

    assert_selector "a[aria-current=page].text-ink", text: "Squad"
    assert_no_selector "a[aria-current=page]", text: "Rankings"
  end
end
