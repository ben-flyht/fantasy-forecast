require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Allow real HTTP connections for system tests (WebDriver needs it)
  setup do
    WebMock.allow_net_connect!
  end

  teardown do
    WebMock.disable_net_connect!
  end
end
