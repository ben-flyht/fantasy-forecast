require "test_helper"
require "webmock/minitest"

class Fpl::SyncPlayersTest < ActiveSupport::TestCase
  def setup
    # Clear all players and teams to ensure clean tests
    Player.destroy_all
    Team.destroy_all
    @fixture_data = JSON.parse(File.read(Rails.root.join("test/fixtures/files/fpl_bootstrap.json")))
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def teardown
    WebMock.allow_net_connect!
  end

  test "stores what FPL says about the player, not just what he has done" do
    stub_fpl_api_success

    Fpl::SyncPlayers.call
    haaland = Player.find_by(fpl_id: 233)

    assert_equal "d", haaland.status, "doubtful, which a numeric flag alone cannot say"
    assert_equal "Knock - 75% chance of playing", haaland.news
    assert_equal Date.new(2000, 7, 21), haaland.birth_date
    assert_equal 178, haaland.region, "nationality, for international absences"
    assert_equal Date.new(2022, 7, 1), haaland.team_join_date
    assert_equal 9, haaland.squad_number
    assert haaland.selectable
    assert_not haaland.departed
    assert_not_nil haaland.news_added
  end

  test "stores the league table and strength ratings for a club" do
    stub_fpl_api_success

    Fpl::SyncPlayers.call
    city = Team.find_by(name: "Manchester City")

    assert_equal 38, city.played
    assert_equal 83, city.points
    assert_equal 2, city.league_position
    assert_equal 1360, city.strength_attack_home, "the fields Schedule needs, which nothing was populating"
    assert_equal 1320, city.strength_defence_away
  end

  test "leaves last season's strength alone when FPL has zeroed it for the summer" do
    stub_fpl_api_success
    Fpl::SyncPlayers.call
    Team.find_by(name: "Manchester City").update!(strength_attack_home: 1360)

    zeroed = @fixture_data.deep_dup
    zeroed["teams"].each { |t| t.merge!("strength_overall_home" => 0, "strength_attack_home" => 0) }
    stub_request(:get, Fpl::Api::BOOTSTRAP_URL)
      .to_return(status: 200, body: zeroed.to_json, headers: { "Content-Type" => "application/json" })
    Fpl::SyncPlayers.call

    assert_equal 1360, Team.find_by(name: "Manchester City").strength_attack_home,
                 "a summer of noughts must not read as a verdict on the club"
  end

  test "successfully syncs players from FPL API" do
    stub_fpl_api_success

    assert_difference "Player.count", 6 do
      result = Fpl::SyncPlayers.call
      assert result, "FPL sync should return true on success"
    end

    # Verify specific players were created correctly
    haaland = Player.find_by(fpl_id: 233)
    assert_not_nil haaland
    assert_equal "Erling", haaland.first_name
    assert_equal "Haaland", haaland.last_name
    assert_equal "Erling Haaland", haaland.name
    assert_equal "Haaland", haaland.short_name
    assert_equal "Manchester City", haaland.team.name
    assert_equal "forward", haaland.position

    salah = Player.find_by(fpl_id: 253)
    assert_not_nil salah
    assert_equal "Mohamed", salah.first_name
    assert_equal "Salah", salah.last_name
    assert_equal "Mohamed Salah", salah.name
    assert_equal "Salah", salah.short_name
    assert_equal "Liverpool", salah.team.name
    assert_equal "forward", salah.position

    alisson = Player.find_by(fpl_id: 254)
    assert_not_nil alisson
    assert_equal "Alisson", alisson.first_name
    assert_equal "Becker", alisson.last_name
    assert_equal "Alisson Becker", alisson.name
    assert_equal "Liverpool", alisson.team.name
    assert_equal "goalkeeper", alisson.position
  end

  test "updates existing players instead of duplicating" do
    # Create test team and existing player
    test_team = Team.create!(name: "Old Team", short_name: "OLD", fpl_id: 95)
    existing_player = Player.create!(
      first_name: "Old",
      last_name: "Name",
      team: test_team,
      position: "midfielder",
      fpl_id: 233
    )

    stub_fpl_api_success

    # Should add 5 new players (6 total - 1 existing)
    assert_difference "Player.count", 5 do
      Fpl::SyncPlayers.call
    end

    # Verify player was updated, not duplicated
    existing_player.reload
    assert_equal "Erling", existing_player.first_name
    assert_equal "Haaland", existing_player.last_name
    assert_equal "Erling Haaland", existing_player.name
    assert_equal "Manchester City", existing_player.team.name
    assert_equal "forward", existing_player.position
    assert_equal 233, existing_player.fpl_id

    # Verify we have the expected total count
    assert_equal 6, Player.count
  end

  test "handles API failure gracefully" do
    stub_fpl_api_failure

    assert_no_difference "Player.count" do
      result = Fpl::SyncPlayers.call
      assert_not result, "FPL sync should return false on failure"
    end
  end

  test "handles invalid JSON response" do
    stub_request(:get, Fpl::Api::BOOTSTRAP_URL)
      .to_return(status: 200, body: "invalid json", headers: {})

    assert_no_difference "Player.count" do
      result = Fpl::SyncPlayers.call
      assert_not result, "FPL sync should return false on invalid JSON"
    end
  end

  test "maps position types correctly" do
    stub_fpl_api_success

    Fpl::SyncPlayers.call

    # Check position mappings
    gk = Player.find_by(fpl_id: 254)  # Alisson
    assert_equal "goalkeeper", gk.position

    def_player = Player.find_by(fpl_id: 252)  # TAA
    assert_equal "defender", def_player.position

    mid_player = Player.find_by(fpl_id: 218)  # De Bruyne
    assert_equal "midfielder", mid_player.position

    fwd_player = Player.find_by(fpl_id: 233)  # Haaland
    assert_equal "forward", fwd_player.position
  end

  test "builds teams hash correctly" do
    service = Fpl::SyncPlayers.new
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

    stub_request(:get, Fpl::Api::BOOTSTRAP_URL)
      .to_return(status: 200, body: malformed_data.to_json, headers: {})

    assert_no_difference "Player.count" do
      Fpl::SyncPlayers.call
    end
  end

  test "persists per-90, minutes and set-piece snapshot statistics" do
    gameweek = Gameweek.find_or_create_by!(fpl_id: 8801) do |g|
      g.name = "Gameweek 8801"
      g.start_time = 1.day.ago
      g.is_current = true
    end

    element = {
      "id" => 8801, "element_type" => 3, "team" => 90, "code" => 8801,
      "first_name" => "Snap", "second_name" => "Shot", "web_name" => "Shot",
      "expected_goal_involvements_per_90" => 0.85, "saves_per_90" => 0.0,
      "defensive_contribution_per_90" => 12.4, "starts_per_90" => 0.9,
      "penalties_order" => 1, "corners_and_indirect_freekicks_order" => 2
    }
    stub_request(:get, Fpl::Api::BOOTSTRAP_URL).to_return(
      status: 200, headers: {},
      body: { "teams" => [ { "id" => 90, "name" => "Snap FC", "short_name" => "SNP", "code" => 8890 } ],
              "elements" => [ element ] }.to_json
    )

    Fpl::SyncPlayers.call

    player = Player.find_by(fpl_id: 8801)
    stats = Statistic.where(player: player, gameweek: gameweek).pluck(:type, :value).to_h
    assert_in_delta 0.85, stats["expected_goal_involvements_per_90"], 0.001
    assert_in_delta 12.4, stats["defensive_contribution_per_90"], 0.001
    assert_in_delta 0.9, stats["starts_per_90"], 0.001
    assert_equal 1.0, stats["penalties_order"]
    assert_equal 2.0, stats["corners_freekicks_order"]
  end

  # The fuller performance record the comparison table draws on: a typo in the mapping
  # would silently leave these blank, so the mapping itself is asserted.
  test "persists the season totals and indices the comparison table reads" do
    gameweek = Gameweek.find_or_create_by!(fpl_id: 8802) do |g|
      g.name = "Gameweek 8802"
      g.start_time = 1.day.ago
      g.is_current = true
    end

    element = {
      "id" => 8802, "element_type" => 3, "team" => 90, "code" => 8802,
      "first_name" => "Perf", "second_name" => "Record", "web_name" => "Record",
      "goals_scored" => 9, "expected_goals" => 7.6, "own_goals" => 1,
      "bps" => 540, "ict_index" => 145.2, "threat" => 88.0
    }
    stub_request(:get, Fpl::Api::BOOTSTRAP_URL).to_return(
      status: 200, headers: {},
      body: { "teams" => [ { "id" => 90, "name" => "Snap FC", "short_name" => "SNP", "code" => 8890 } ],
              "elements" => [ element ] }.to_json
    )

    Fpl::SyncPlayers.call

    player = Player.find_by(fpl_id: 8802)
    stats = Statistic.where(player: player, gameweek: gameweek).pluck(:type, :value).to_h
    assert_equal 9.0, stats["season_goals"]
    assert_in_delta 7.6, stats["season_expected_goals"], 0.001
    assert_equal 1.0, stats["season_own_goals"]
    assert_equal 540.0, stats["season_bps"]
    assert_in_delta 145.2, stats["season_ict_index"], 0.001
    assert_in_delta 88.0, stats["season_threat"], 0.001
  end

  test "attaches snapshot statistics to the next gameweek pre-season" do
    # Fresh slate: no current gameweek, a single upcoming gameweek is next.
    Gameweek.update_all(is_current: false, is_next: false)
    gameweek = Gameweek.find_or_create_by!(fpl_id: 8802) do |g|
      g.name = "Gameweek 8802"
      g.start_time = 1.day.from_now
    end
    gameweek.update!(is_current: false, is_next: true)

    stub_request(:get, Fpl::Api::BOOTSTRAP_URL).to_return(
      status: 200, headers: {},
      body: { "teams" => [ { "id" => 91, "name" => "Pre FC", "short_name" => "PRE", "code" => 8891 } ],
              "elements" => [ {
                "id" => 8802, "element_type" => 3, "team" => 91, "code" => 8802,
                "first_name" => "Pre", "second_name" => "Season", "web_name" => "Season",
                "selected_by_percent" => "12.5", "form" => "3.2"
              } ] }.to_json
    )

    Fpl::SyncPlayers.call

    player = Player.find_by(fpl_id: 8802)
    stats = Statistic.where(player: player, gameweek: gameweek).pluck(:type, :value).to_h
    assert_in_delta 12.5, stats["selected_by_percent"], 0.001
    assert_in_delta 3.2, stats["form"], 0.001
  end

  private

  def stub_fpl_api_success
    stub_request(:get, Fpl::Api::BOOTSTRAP_URL)
      .to_return(status: 200, body: @fixture_data.to_json, headers: {})
  end

  def stub_fpl_api_failure
    stub_request(:get, Fpl::Api::BOOTSTRAP_URL)
      .to_return(status: 500, body: "Internal Server Error", headers: {})
  end
end
