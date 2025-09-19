require "test_helper"
require "webmock/minitest"

class FplSyncPlayersTest < ActiveSupport::TestCase
  def setup
    # Clear all players to ensure clean tests
    Player.destroy_all
    @fixture_data = JSON.parse(File.read(Rails.root.join("test/fixtures/files/fpl_bootstrap.json")))
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def teardown
    WebMock.allow_net_connect!
  end

  test "successfully syncs players from FPL API" do
    stub_fpl_api_success

    assert_difference "Player.count", 6 do
      result = FplSyncPlayers.call
      assert result, "FPL sync should return true on success"
    end

    # Verify specific players were created correctly
    haaland = Player.find_by(fpl_id: 233)
    assert_not_nil haaland
    assert_equal "Erling Haaland", haaland.name
    assert_equal "Haaland", haaland.short_name
    assert_equal "Manchester City", haaland.team
    assert_equal "FWD", haaland.position

    salah = Player.find_by(fpl_id: 253)
    assert_not_nil salah
    assert_equal "Mohamed Salah", salah.name
    assert_equal "Salah", salah.short_name
    assert_equal "Liverpool", salah.team
    assert_equal "FWD", salah.position

    alisson = Player.find_by(fpl_id: 254)
    assert_not_nil alisson
    assert_equal "Alisson Becker", alisson.name
    assert_equal "Liverpool", alisson.team
    assert_equal "GK", alisson.position
  end

  test "updates existing players instead of duplicating" do
    # Create existing player
    existing_player = Player.create!(
      name: "Old Name",
      team: "Old Team",
      position: "MID",
      fpl_id: 233
    )

    stub_fpl_api_success

    # Should add 5 new players (6 total - 1 existing)
    assert_difference "Player.count", 5 do
      FplSyncPlayers.call
    end

    # Verify player was updated, not duplicated
    existing_player.reload
    assert_equal "Erling Haaland", existing_player.name
    assert_equal "Manchester City", existing_player.team
    assert_equal "FWD", existing_player.position
    assert_equal 233, existing_player.fpl_id

    # Verify we have the expected total count
    assert_equal 6, Player.count
  end

  test "handles API failure gracefully" do
    stub_fpl_api_failure

    assert_no_difference "Player.count" do
      result = FplSyncPlayers.call
      assert_not result, "FPL sync should return false on failure"
    end
  end

  test "handles invalid JSON response" do
    stub_request(:get, FplSyncPlayers::FPL_API_URL)
      .to_return(status: 200, body: "invalid json", headers: {})

    assert_no_difference "Player.count" do
      result = FplSyncPlayers.call
      assert_not result, "FPL sync should return false on invalid JSON"
    end
  end

  test "maps position types correctly" do
    stub_fpl_api_success

    FplSyncPlayers.call

    # Check position mappings
    gk = Player.find_by(fpl_id: 254)  # Alisson
    assert_equal "GK", gk.position

    def_player = Player.find_by(fpl_id: 252)  # TAA
    assert_equal "DEF", def_player.position

    mid_player = Player.find_by(fpl_id: 218)  # De Bruyne
    assert_equal "MID", mid_player.position

    fwd_player = Player.find_by(fpl_id: 233)  # Haaland
    assert_equal "FWD", fwd_player.position
  end

  test "builds teams hash correctly" do
    service = FplSyncPlayers.new
    teams_data = @fixture_data["teams"]

    teams_hash = service.send(:build_teams_hash, teams_data)

    assert_equal "Arsenal", teams_hash[1]
    assert_equal "Liverpool", teams_hash[2]
    assert_equal "Manchester City", teams_hash[3]
    assert_equal "Chelsea", teams_hash[4]
  end

  test "skips players with missing data" do
    # Create a malformed response with missing team data
    malformed_data = {
      "teams" => [ { "id" => 1, "name" => "Arsenal" } ],
      "elements" => [
        {
          "id" => 999,
          "first_name" => "Test",
          "second_name" => "Player",
          "team" => 99,  # Non-existent team
          "element_type" => 4
        }
      ]
    }

    stub_request(:get, FplSyncPlayers::FPL_API_URL)
      .to_return(status: 200, body: malformed_data.to_json, headers: {})

    assert_no_difference "Player.count" do
      FplSyncPlayers.call
    end
  end

  private

  def stub_fpl_api_success
    stub_request(:get, FplSyncPlayers::FPL_API_URL)
      .to_return(status: 200, body: @fixture_data.to_json, headers: {})
  end

  def stub_fpl_api_failure
    stub_request(:get, FplSyncPlayers::FPL_API_URL)
      .to_return(status: 500, body: "Internal Server Error", headers: {})
  end
end
