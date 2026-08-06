ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # A PNG says how big it is in the eight bytes after its header, which is the
    # cheapest way to ask a share card whether it came out the shape social sites
    # ask for.
    def png_size(bytes)
      bytes[16, 8].unpack("N2")
    end
  end
end
