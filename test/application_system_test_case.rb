require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Allow real HTTP connections for system tests (WebDriver needs it)
  setup do
    WebMock.allow_net_connect!
  end

  # Localhost stays open afterwards. Capybara shuts the browser down at exit,
  # long after the last teardown has run, and closing the door on the driver's
  # own port fails the whole suite on the way out.
  teardown do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
