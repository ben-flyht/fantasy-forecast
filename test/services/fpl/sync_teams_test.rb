require "test_helper"
require "webmock/minitest"

class Fpl::SyncTeamsTest < ActiveSupport::TestCase
  def setup
    Player.destroy_all
    Team.destroy_all
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def teardown
    WebMock.allow_net_connect!
  end

  test "ingests team strength ratings from the FPL API" do
    body = { "teams" => [ {
      "id" => 1, "name" => "Arsenal", "short_name" => "ARS", "code" => 3,
      "strength" => 5,
      "strength_overall_home" => 1340, "strength_overall_away" => 1350,
      "strength_attack_home" => 1300, "strength_attack_away" => 1320,
      "strength_defence_home" => 1280, "strength_defence_away" => 1290
    } ] }
    stub_request(:get, Fpl::SyncTeams::FPL_API_URL)
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })

    assert Fpl::SyncTeams.call

    team = Team.find_by(fpl_id: 1)
    assert_equal 5, team.strength
    assert_equal 1280, team.strength_defence_home
    assert_equal 1320, team.strength_attack_away
    # Venue-aware helpers used by the schedule column
    assert_equal 1280, team.defence_strength(:home)
    assert_equal 1320, team.attack_strength(:away)
  end
end
