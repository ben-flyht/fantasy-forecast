require "test_helper"

class GoogleAnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @original = ENV["GOOGLE_ANALYTICS_ID"]
    ENV["GOOGLE_ANALYTICS_ID"] = "G-TEST123"
  end

  teardown do
    ENV["GOOGLE_ANALYTICS_ID"] = @original
  end

  test "the config leaves the page view to the turbo:load listener" do
    get root_path

    assert_includes response.body, "gtag('config', 'G-TEST123', { send_page_view: false });"
    assert_includes response.body, "document.addEventListener('turbo:load'"
  end

  test "nothing is rendered without an id" do
    ENV["GOOGLE_ANALYTICS_ID"] = nil

    get root_path

    assert_not_includes response.body, "googletagmanager"
  end
end
