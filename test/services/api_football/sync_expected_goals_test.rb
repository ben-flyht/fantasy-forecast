require "test_helper"

class ApiFootball::SyncExpectedGoalsTest < ActiveSupport::TestCase
  def setup
    @team1 = Team.create!(name: "Home Team", short_name: "HOM", fpl_id: 901, api_football_id: 1001)
    @team2 = Team.create!(name: "Away Team", short_name: "AWY", fpl_id: 902, api_football_id: 1002)

    @gameweek = Gameweek.create!(
      fpl_id: 901,
      name: "Gameweek 901",
      start_time: 1.day.from_now,
      is_next: true
    )

    @match = Match.create!(
      gameweek: @gameweek,
      home_team: @team1,
      away_team: @team2,
      fpl_id: 9001
    )
  end

  test "returns false when no gameweek available" do
    Gameweek.update_all(is_next: false, is_current: false)

    result = ApiFootball::SyncExpectedGoals.call(gameweek: nil)
    assert_equal false, result
  end

  test "returns false when API returns no fixtures" do
    stub_api_fixtures([])

    result = ApiFootball::SyncExpectedGoals.call(gameweek: @gameweek)
    assert_equal false, result
  end

  test "syncs expected goals for matching fixture" do
    fixture_data = build_fixture(@team1.api_football_id, @team2.api_football_id, 12345)
    odds_data = build_odds_data

    stub_api_fixtures([ fixture_data ])
    stub_api_odds(12345, odds_data)

    result = ApiFootball::SyncExpectedGoals.call(gameweek: @gameweek)

    assert_equal true, result
    @match.reload
    assert_not_nil @match.home_team_expected_goals
    assert_not_nil @match.away_team_expected_goals
  end

  test "handles missing api_football_id on teams" do
    @team1.update!(api_football_id: nil)

    fixture_data = build_fixture(1001, 1002, 12345)
    stub_api_fixtures([ fixture_data ])

    result = ApiFootball::SyncExpectedGoals.call(gameweek: @gameweek)

    assert_equal true, result
    @match.reload
    assert_nil @match.home_team_expected_goals
  end

  test "handles API client errors gracefully" do
    stub_request(:get, /v3\.football\.api-sports\.io/)
      .to_return(status: 500, body: "Internal Server Error")

    result = ApiFootball::SyncExpectedGoals.call(gameweek: @gameweek)
    assert_equal false, result
  end

  test "handles missing odds data for fixture" do
    fixture_data = build_fixture(@team1.api_football_id, @team2.api_football_id, 12345)

    stub_api_fixtures([ fixture_data ])
    stub_api_odds(12345, [])

    result = ApiFootball::SyncExpectedGoals.call(gameweek: @gameweek)

    assert_equal true, result
    @match.reload
    assert_nil @match.home_team_expected_goals
  end

  private

  def stub_api_fixtures(fixtures)
    stub_request(:get, /v3\.football\.api-sports\.io\/fixtures/)
      .to_return(
        status: 200,
        body: { response: fixtures }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_api_odds(fixture_id, odds_data)
    stub_request(:get, /v3\.football\.api-sports\.io\/odds/)
      .to_return(
        status: 200,
        body: { response: odds_data }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def build_fixture(home_id, away_id, fixture_id)
    {
      "fixture" => { "id" => fixture_id },
      "teams" => {
        "home" => { "id" => home_id, "name" => "Home Team" },
        "away" => { "id" => away_id, "name" => "Away Team" }
      }
    }
  end

  def build_odds_data
    [ {
      "bookmakers" => [ {
        "name" => "Bet365",
        "bets" => [
          {
            "id" => 40,
            "values" => [
              { "value" => "0", "odd" => "5.0" },
              { "value" => "1", "odd" => "3.0" },
              { "value" => "2", "odd" => "4.0" },
              { "value" => "3", "odd" => "8.0" }
            ]
          },
          {
            "id" => 41,
            "values" => [
              { "value" => "0", "odd" => "4.0" },
              { "value" => "1", "odd" => "3.0" },
              { "value" => "2", "odd" => "5.0" }
            ]
          }
        ]
      } ]
    } ]
  end
end
