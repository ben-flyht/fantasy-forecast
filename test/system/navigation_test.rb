require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze
  DESKTOP = [ 1400, 1400 ].freeze

  teardown do
    page.driver.browser.manage.window.resize_to(*DESKTOP)
  end

  test "a phone carries every destination in a bar at the foot of the screen" do
    on_a_phone
    visit root_path

    %w[Rankings Compare Squad Captain Play].each do |label|
      assert_selector "nav[aria-label=Main] a", text: label, visible: true
    end
    assert_no_selector "nav[aria-label=Site] a", text: "Squad", visible: true
  end

  test "a tab goes where it says, and then says that is where you are" do
    on_a_phone
    visit root_path

    within("nav[aria-label=Main]") { click_link "Squad" }

    assert_current_path squad_path
    assert_selector "nav[aria-label=Main] a[aria-current=page]", text: "Squad"
  end

  test "the bar stays out of the way of the page's last line" do
    on_a_phone
    visit root_path

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

    bar_top = page.evaluate_script("document.querySelector('nav[aria-label=Main]').getBoundingClientRect().top")
    footer_bottom = page.evaluate_script("document.querySelector('footer').getBoundingClientRect().bottom")
    assert_operator footer_bottom, :<=, bar_top
  end

  test "a desktop has the row at the top and no bar" do
    page.driver.browser.manage.window.resize_to(*DESKTOP)
    visit root_path

    assert_selector "nav[aria-label=Site] a", text: "Squad", visible: true
    assert_no_selector "nav[aria-label=Main] a", visible: true
  end

  private

  def on_a_phone
    page.driver.browser.manage.window.resize_to(*PHONE)
  end
end
