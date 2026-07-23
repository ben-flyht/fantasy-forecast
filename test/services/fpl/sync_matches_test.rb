require "test_helper"
require "webmock/minitest"

class Fpl::SyncMatchesTest < ActiveSupport::TestCase
  def setup
    Match.destroy_all
    WebMock.disable_net_connect!(allow_localhost: true)
    @gameweek = Gameweek.find_or_create_by!(fpl_id: 9001) { |g| g.name = "Gameweek 9001"; g.start_time = 1.week.from_now }
    @home = Team.find_or_create_by!(fpl_id: 9001) { |t| t.name = "Home FC"; t.short_name = "HOM"; t.code = 9001 }
    @away = Team.find_or_create_by!(fpl_id: 9007) { |t| t.name = "Away FC"; t.short_name = "AWY"; t.code = 9007 }
  end

  def teardown
    WebMock.allow_net_connect!
  end

  test "ingests official fixture difficulty ratings" do
    stub_request(:get, Fpl::SyncMatches::FPL_FIXTURES_URL)
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: [ {
        "id" => 9100, "event" => 9001, "team_h" => 9001, "team_a" => 9007,
        "team_h_difficulty" => 2, "team_a_difficulty" => 5
      } ].to_json)

    assert Fpl::SyncMatches.call

    match = Match.find_by(fpl_id: 9100)
    assert_equal 2, match.home_difficulty
    assert_equal 5, match.away_difficulty
    # difficulty_for reads the rating from the given team's perspective
    assert_equal 2, match.difficulty_for(@home.id)
    assert_equal 5, match.difficulty_for(@away.id)
  end
end
