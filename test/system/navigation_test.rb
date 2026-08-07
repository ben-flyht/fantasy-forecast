require "application_system_test_case"

# The menu behind the button is JavaScript, so no controller test can reach it. A
# controller test can only say the links are in the markup, and they were in the
# markup all along: what a phone could not do was open the thing holding them.
class NavigationTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze

  setup do
    page.driver.browser.manage.window.resize_to(*PHONE)
  end

  teardown do
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  # The button is an icon, so it has no text to click by: its name is its aria-label,
  # which is also the only name a screen reader has for it.
  def open_menu = find("button[aria-label=Menu]").click

  test "the links are behind the button on a phone, and the button opens them" do
    visit root_path

    assert_no_selector "#navigation-menu a", visible: true
    assert_selector "button[aria-label=Menu][aria-expanded=false]"

    open_menu

    assert_selector "#navigation-menu a", text: "Squad", visible: true
    assert_selector "button[aria-label=Menu][aria-expanded=true]"
  end

  test "escape closes it, so it is not a trap on a keyboard" do
    visit root_path
    open_menu
    assert_selector "#navigation-menu a", visible: true

    find("body").send_keys :escape

    assert_no_selector "#navigation-menu a", visible: true
  end

  test "clicking away closes it" do
    visit root_path
    open_menu
    assert_selector "#navigation-menu a", visible: true

    find("main").click

    assert_no_selector "#navigation-menu a", visible: true
  end

  test "a link behind the button goes where it says" do
    visit root_path
    open_menu

    within("#navigation-menu") { click_link "Squad" }

    assert_current_path squad_path
  end
end
