require "test_helper"

class ApiFootball::ExpectedGoalsCalculatorTest < ActiveSupport::TestCase
  test "returns nil when odds_data is nil" do
    result = ApiFootball::ExpectedGoalsCalculator.call(odds_data: nil)
    assert_equal [ nil, nil ], result
  end

  test "returns nil when odds_data is empty" do
    result = ApiFootball::ExpectedGoalsCalculator.call(odds_data: [])
    assert_equal [ nil, nil ], result
  end

  test "returns nil when no bookmakers have required bets" do
    odds_data = [ { "bookmakers" => [ { "name" => "TestBook", "bets" => [] } ] } ]
    result = ApiFootball::ExpectedGoalsCalculator.call(odds_data: odds_data)
    assert_equal [ nil, nil ], result
  end

  test "calculates expected goals from exact goals odds" do
    odds_data = [ build_odds_data ]
    home_xg, away_xg = ApiFootball::ExpectedGoalsCalculator.call(odds_data: odds_data)

    assert_not_nil home_xg
    assert_not_nil away_xg
    assert_in_delta 1.5, home_xg, 0.5
    assert_in_delta 1.2, away_xg, 0.5
  end

  test "prefers Bet365 when available" do
    bet365_data = build_bookmaker_data("Bet365", home_goals: [ 0, 1, 2 ], away_goals: [ 0, 1, 2 ])
    other_data = build_bookmaker_data("OtherBook", home_goals: [ 0, 1, 2, 3 ], away_goals: [ 0, 1, 2, 3 ])

    odds_data = [ { "bookmakers" => [ other_data, bet365_data ] } ]
    home_xg, away_xg = ApiFootball::ExpectedGoalsCalculator.call(odds_data: odds_data)

    assert_not_nil home_xg
    assert_not_nil away_xg
  end

  test "handles 'more X' outcomes in goals" do
    bookmaker = {
      "name" => "TestBook",
      "bets" => [
        {
          "id" => 40,
          "values" => [
            { "value" => "0", "odd" => "5.0" },
            { "value" => "1", "odd" => "3.0" },
            { "value" => "2", "odd" => "3.5" },
            { "value" => "more 2", "odd" => "4.0" }
          ]
        },
        {
          "id" => 41,
          "values" => [
            { "value" => "0", "odd" => "4.0" },
            { "value" => "1", "odd" => "3.0" },
            { "value" => "more 1", "odd" => "3.0" }
          ]
        }
      ]
    }

    odds_data = [ { "bookmakers" => [ bookmaker ] } ]
    home_xg, away_xg = ApiFootball::ExpectedGoalsCalculator.call(odds_data: odds_data)

    assert_not_nil home_xg
    assert_not_nil away_xg
  end

  test "ignores invalid odds values" do
    bookmaker = {
      "name" => "TestBook",
      "bets" => [
        {
          "id" => 40,
          "values" => [
            { "value" => "0", "odd" => "5.0" },
            { "value" => "1", "odd" => "0.5" },  # Invalid: odds <= 1
            { "value" => "2", "odd" => "3.5" }
          ]
        },
        {
          "id" => 41,
          "values" => [
            { "value" => "0", "odd" => "4.0" },
            { "value" => "invalid", "odd" => "3.0" },  # Invalid value
            { "value" => "1", "odd" => "3.0" }
          ]
        }
      ]
    }

    odds_data = [ { "bookmakers" => [ bookmaker ] } ]
    home_xg, away_xg = ApiFootball::ExpectedGoalsCalculator.call(odds_data: odds_data)

    assert_not_nil home_xg
    assert_not_nil away_xg
  end

  private

  def build_odds_data
    { "bookmakers" => [ build_bookmaker_data("Bet365") ] }
  end

  def build_bookmaker_data(name, home_goals: [ 0, 1, 2, 3 ], away_goals: [ 0, 1, 2 ])
    {
      "name" => name,
      "bets" => [
        {
          "id" => 40,  # HOME_TEAM_EXACT_GOALS_BET_ID
          "values" => home_goals.map { |g| { "value" => g.to_s, "odd" => (3.0 + g).to_s } }
        },
        {
          "id" => 41,  # AWAY_TEAM_EXACT_GOALS_BET_ID
          "values" => away_goals.map { |g| { "value" => g.to_s, "odd" => (3.5 + g).to_s } }
        }
      ]
    }
  end
end
