require "test_helper"

class ExpectedPointsTest < ActiveSupport::TestCase
  def ranking(player_id, position: "midfielder", team_id: 1)
    ConsensusRanking::Ranking.new(player_id: player_id, position: position, team_id: team_id, score: 100)
  end

  def fixture(difficulty = 3, opponent: "Someone", home: true)
    { difficulty: difficulty, opponent: opponent, home: home }
  end

  # A regular starter with a decent record behind him.
  def regular(minutes: 3000.0, xg: 0.30, xgi: 0.50, clean_sheets: 0.30, owned: 5.0, cost: 60.0)
    {
      "last_season_minutes" => minutes, "expected_goals_per_90" => xg,
      "expected_goal_involvements_per_90" => xgi, "clean_sheets_per_90" => clean_sheets,
      "selected_by_percent" => owned, "now_cost" => cost
    }
  end

  def forecast(rankings, stats, fixtures: { 1 => [ fixture ] }, managers: nil, movers: [])
    ExpectedPoints.new(rankings, stats: stats, fixtures_by_team: fixtures,
                       season_started: false, managers: managers, movers: movers).call
  end

  test "expected points is minutes, times what he is worth per 90, times the games ahead" do
    result = forecast([ ranking(1) ], { 1 => regular })

    # 90 minutes of a 0.3 xG, 0.2 xA midfielder on a level fixture: two points for
    # turning up, plus what he is worth on top, shrunk for sample size
    assert_in_delta 4.1, result[1][:points], 0.1
  end

  test "before the season, minutes are read against a full campaign" do
    rankings = [ ranking(1), ranking(2) ]
    stats = { 1 => regular(minutes: 3000.0), 2 => regular(minutes: 900.0) }

    # what the pipeline passes pre-season: no gameweeks finished yet
    result = ExpectedPoints.new(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                season_started: false, gameweeks_played: 0).call

    assert_equal 90, result[1][:working][:minutes], "a season of football makes a regular"
    assert result[2][:working][:minutes] < 60,
           "a bit-part player is not a regular just because no gameweek has finished yet"
  end

  test "a player who does not play scores nothing, however good he is" do
    elite = regular(xg: 1.0, xgi: 1.4)
    rankings = [ ranking(1), ranking(2) ]
    stats = { 1 => elite.merge("chance_of_playing" => 0.0), 2 => regular }

    result = forecast(rankings, stats)

    assert_equal 0.0, result[1][:points], "ruled out is nought, not merely a lower score"
    assert result[2][:points] > result[1][:points]
  end

  test "a blank gameweek is nought points, and a double is worth about twice one game" do
    rankings = [ ranking(1, team_id: 1), ranking(2, team_id: 2), ranking(3, team_id: 3) ]
    stats = { 1 => regular, 2 => regular, 3 => regular }
    fixtures = { 1 => [ fixture ], 2 => [ fixture, fixture ], 3 => [] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_equal 0.0, result[3][:points], "no game, no points"
    assert_in_delta result[1][:points] * 2, result[2][:points], 0.05, "two games, two goes at it"
  end

  test "a kind fixture is worth more than a hard one, but not wildly so" do
    rankings = [ ranking(1, team_id: 1), ranking(2, team_id: 2) ]
    stats = { 1 => regular, 2 => regular }
    fixtures = { 1 => [ fixture(2) ], 2 => [ fixture(5) ] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert result[1][:points] > result[2][:points]
    assert result[1][:points] < result[2][:points] * 1.3, "difficulty one to five does not know more than that"
  end

  test "a player with no record at all cannot be forecast" do
    result = forecast([ ranking(1), ranking(2) ], { 1 => regular, 2 => {} })

    assert_nil result[2][:points], "unknown is not the same as nought"
    assert_empty result[2][:working], "nothing to show for a player we cannot forecast"
  end

  test "a rate built from a handful of minutes is not taken at face value" do
    rankings = [ ranking(1), ranking(2) ]
    stats = {
      1 => regular(minutes: 30.0, xg: 3.0, xgi: 4.0), # one wild cameo
      2 => regular(minutes: 3000.0, xg: 0.5, xgi: 0.8)
    }

    result = forecast(rankings, stats)

    assert result[2][:points] > result[1][:points], "a season of evidence beats half an hour of luck"
  end

  # A field with a spread of records, so the crowd's ordering has a shape to be
  # read off. Players 1 and 2 are given identical records in the middle of it.
  def crowded_field(owned:, cost:)
    rankings = (1..12).map { |id| ranking(id, position: "forward") }
    stats = (3..12).to_h { |id| [ id, regular(xg: 0.05 * id, xgi: 0.08 * id, owned: 3.0, cost: 55.0) ] }
    stats[1] = regular(xg: 0.3, xgi: 0.45, owned: owned.first, cost: cost.first)
    stats[2] = regular(xg: 0.3, xgi: 0.45, owned: owned.last, cost: cost.last)
    [ rankings, stats ]
  end

  test "between two identical records, the crowd decides" do
    rankings, stats = crowded_field(owned: [ 30.0, 0.5 ], cost: [ 60.0, 60.0 ])

    result = forecast(rankings, stats)

    assert result[1][:points] > result[2][:points],
           "same player on paper, but one of them the game has picked and the other it has not"
  end

  test "paying more for the same backing counts as the stronger vote" do
    rankings, stats = crowded_field(owned: [ 20.0, 20.0 ], cost: [ 80.0, 65.0 ])

    result = forecast(rankings, stats)

    assert result[1][:points] > result[2][:points],
           "a fifth of the game funding the dearer one is the costlier decision"
  end

  test "the crowd can reorder a position but not invent a player better than any in it" do
    rankings, stats = crowded_field(owned: [ 60.0, 3.0 ], cost: [ 90.0, 55.0 ])
    stats[1] = regular(xg: 0.0, xgi: 0.0, owned: 60.0, cost: 90.0) # adored, no record at all

    result = forecast(rankings, stats)
    points = result.values.filter_map { |f| f[:points] }.sort.reverse

    assert_includes points.first(4), result[1][:points], "their backing carries him near the top"
    assert result[1][:points] < points.first, "but never past the best player we can actually measure"
  end

  test "a rush for the exit drops a player hard and at once" do
    rankings = [ ranking(1), ranking(2) ]
    owned = regular(owned: 10.0) # a tenth of 10m managers, so a million owners
    stats = {
      1 => owned.merge("transfers_out" => 400_000.0, "transfers_in" => 10_000.0), # two owners in five leaving
      2 => owned
    }

    result = forecast(rankings, stats, managers: 10_000_000)

    assert_in_delta result[2][:points] * 0.61, result[1][:points], 0.1,
                    "the crowd sells on news we have not seen yet, so it counts nearly in full"
  end

  test "the same sell-off means far less from a much larger owner base" do
    rankings = [ ranking(1), ranking(2) ]
    stats = {
      1 => regular(owned: 40.0).merge("transfers_out" => 400_000.0),
      2 => regular(owned: 40.0)
    }

    result = forecast(rankings, stats, managers: 10_000_000)

    assert result[1][:points] > result[2][:points] * 0.85,
           "400,000 sales out of four million owners is a trickle, not a rout"
  end

  test "buying counts for far less than selling" do
    rankings = [ ranking(1), ranking(2) ]
    owned = regular(owned: 10.0)
    stats = { 1 => owned.merge("transfers_in" => 900_000.0), 2 => owned.merge("transfers_out" => 900_000.0) }

    result = forecast(rankings, stats, managers: 10_000_000)
    lift = result[1][:points] / result[2][:points]

    assert lift > 2.0, "a rout takes far more off than a rush puts on"
  end

  test "transfers say nothing until FPL publishes how many managers there are" do
    rankings = [ ranking(1), ranking(2) ]
    stats = { 1 => regular.merge("transfers_out" => 900_000.0), 2 => regular }

    result = forecast(rankings, stats) # no manager count, as before the season

    assert_equal result[2][:points], result[1][:points]
  end

  test "the working stores the figures it multiplied, not sentences about them" do
    result = forecast([ ranking(1, team_id: 1) ], { 1 => regular })
    working = result[1][:working]

    assert_equal 90, working[:minutes]
    assert_in_delta 4.1, working[:per_90], 0.2
    assert_equal 1.0, working[:games], "one ordinary fixture"
    assert_equal [ { name: "Someone", home: true, difficulty: 3 } ], working[:opponents]
    assert working.values.none? { |value| value.is_a?(String) }, "wording belongs in the view"
  end
end
