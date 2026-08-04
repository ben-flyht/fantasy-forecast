require "test_helper"

class Fpl::ApiTest < ActiveSupport::TestCase
  # Counting requests only means anything from a clean slate, and other tests in
  # this worker will have asked FPL for things of their own.
  setup { WebMock.reset! }

  test "asks FPL once, however many syncs want the answer" do
    asked = stub_request(:get, Fpl::Api::BOOTSTRAP_URL)
            .to_return(status: 200, body: { "teams" => [] }.to_json,
                       headers: { "Content-Type" => "application/json" })
    api = Fpl::Api.new

    3.times { api.bootstrap }

    assert_requested asked, times: 1
  end

  test "an endpoint that is down is not waited on again" do
    asked = stub_request(:get, Fpl::Api::BOOTSTRAP_URL).to_return(status: 503)
    api = Fpl::Api.new

    assert_nil api.bootstrap
    assert_nil api.bootstrap, "a refusal is an answer too"
    assert_requested asked, times: 1
  end

  test "a player's summary is read and let go of, not held for the whole run" do
    asked = stub_request(:get, %r{/api/element-summary/1/})
            .to_return(status: 200, body: { "history_past" => [] }.to_json,
                       headers: { "Content-Type" => "application/json" })
    api = Fpl::Api.new

    2.times { api.summary(1) }

    assert_requested asked, times: 2 # seven hundred of these, kept, would not fit
  end

  test "a broken answer is nothing rather than an exception" do
    stub_request(:get, Fpl::Api::BOOTSTRAP_URL).to_return(status: 200, body: "not json")

    assert_nil Fpl::Api.new.bootstrap
  end
end
