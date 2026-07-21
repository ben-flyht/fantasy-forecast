require "test_helper"

module Fpl
  class NewSeasonDetectorTest < ActiveSupport::TestCase
    def setup
      WebMock.disable_net_connect!(allow_localhost: true)
      # Start from a clean, full league we control (fixtures only carry 3 teams
      # with no codes, which the detector can't compare on).
      Fpl::ResetSeason.call
      @codes = (1..20).map { |i| 1000 + i }
      @codes.each_with_index do |code, i|
        Team.create!(name: "Team #{i}", short_name: "T#{i}", fpl_id: i + 1, code: code)
      end
    end

    def teardown
      WebMock.allow_net_connect!
    end

    test "false when the API team codes match what we have stored" do
      stub_teams(@codes)

      assert_not Fpl::NewSeasonDetector.call
    end

    test "true when the team composition has changed (promotion/relegation)" do
      changed = @codes.dup
      changed[0] = 999_999 # a promoted club we've never seen

      stub_teams(changed)

      assert Fpl::NewSeasonDetector.call
    end

    test "false when the API returns fewer than a full league (partial response)" do
      # A truncated payload must never trigger a wipe.
      stub_teams(@codes.first(5))

      assert_not Fpl::NewSeasonDetector.call
    end

    test "false on the first ever sync when no teams are stored" do
      Fpl::ResetSeason.call
      stub_teams((1..20).map { |i| 2000 + i })

      assert_not Fpl::NewSeasonDetector.call
    end

    test "false when the FPL API is unreachable" do
      stub_request(:get, Fpl::NewSeasonDetector::FPL_API_URL)
        .to_return(status: 500, body: "error")

      assert_not Fpl::NewSeasonDetector.call
    end

    private

    def stub_teams(codes)
      body = { "teams" => codes.map { |code| { "code" => code } } }
      stub_request(:get, Fpl::NewSeasonDetector::FPL_API_URL)
        .to_return(status: 200, body: body.to_json, headers: {})
    end
  end
end
