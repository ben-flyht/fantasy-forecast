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
      "last_season_minutes" => minutes, "last_season_expected_goals_per_90" => xg,
      "last_season_expected_goal_involvements_per_90" => xgi,
      "last_season_clean_sheets_per_90" => clean_sheets,
      "selected_by_percent" => owned, "now_cost" => cost
    }
  end

  def forecast(rankings, stats, fixtures: { 1 => [ fixture ] }, managers: nil, movers: [])
    ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: fixtures,
                       season_started: false, managers: managers, movers: movers)
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
    result = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                season_started: false, gameweeks_played: 0)

    assert_equal 90, result[1][:working][:minutes], "a season of football makes a regular"
    assert result[2][:working][:minutes] < 60,
           "a bit-part player is not a regular just because no gameweek has finished yet"
  end

  test "a hair between two players is not rounded into a tie" do
    rankings = [ ranking(1), ranking(2) ]
    stats = { 1 => regular(xgi: 0.500), 2 => regular(xgi: 0.503) }

    result = forecast(rankings, stats)

    assert_in_delta result[1][:points], result[2][:points], 0.05, "the two are all but level"
    assert result[2][:points] > result[1][:points],
           "and the better of them still ranks first: the order is settled by the forecast, not by rounding"
  end

  # What a player's bonus is worth to him, measured against the same player
  # without it. Two gameweeks in, so a full match is a real share of the football
  # played so far.
  def bonus_gain(minutes, bonus)
    played = { "expected_goals_per_90" => 0.30, "expected_goal_involvements_per_90" => 0.50,
               "clean_sheets_per_90" => 0.30, "selected_by_percent" => 5.0,
               "now_cost" => 60.0, "season_minutes" => minutes }
    stats = { 1 => played.merge("season_bonus" => bonus), 2 => played.merge("season_bonus" => 0.0) }

    result = ExpectedPoints.call([ ranking(1), ranking(2) ], stats: stats,
                                fixtures_by_team: { 1 => [ fixture ] },
                                season_started: true, gameweeks_played: 2)
    result[1][:points] - result[2][:points]
  end

  test "bonus counts for less when there is less football behind it" do
    cameo = bonus_gain(45.0, 6.0)
    regular = bonus_gain(200.0, 3.0)

    assert cameo < regular / 2,
           "twice the bonus from a fifth of the football cannot be worth as much as the record"
  end

  test "a player who does not play scores nothing, however good he is" do
    elite = regular(xg: 1.0, xgi: 1.4)
    rankings = [ ranking(1), ranking(2) ]
    stats = { 1 => elite.merge("chance_of_playing" => 0.0), 2 => regular }

    result = forecast(rankings, stats)

    assert_equal 0.0, result[1][:points], "ruled out is nought, not merely a lower score"
    assert result[2][:points] > result[1][:points]
  end

  test "a player who cannot play is judged on his record, not on managers selling him" do
    rankings = [ ranking(1), ranking(2) ]
    stats = { 1 => regular.merge("chance_of_playing" => 0.0), 2 => regular }

    result = forecast(rankings, stats)

    assert_nil result[1][:working][:perf_factor],
               "ruled out, his backing is set aside and his record does the talking"
    assert result[2][:working][:perf_factor], "everybody else's standing is still the market's to lead"
  end

  test "turning up is worth the same whoever the opponent is" do
    rankings = [ ranking(1) ]
    stats = { 1 => regular(xg: 0.0, xgi: 0.0, clean_sheets: 0.0) } # paid for nothing but being there

    kind = forecast(rankings, stats, fixtures: { 1 => [ fixture(1) ] })
    cruel = forecast(rankings, stats, fixtures: { 1 => [ fixture(5) ] })

    assert_equal kind[1][:points], cruel[1][:points],
                 "no opponent can change what a man gets for being on the pitch"
  end

  test "a hard afternoon costs a defender his clean sheet and brings a goalkeeper saves" do
    rankings = [ ranking(1, position: "defender"), ranking(2, position: "goalkeeper") ]
    stats = { 1 => regular(clean_sheets: 0.35),
              2 => regular(clean_sheets: 0.35).merge("last_season_saves_per_90" => 3.0) }

    cruel = forecast(rankings, stats, fixtures: { 1 => [ fixture(5) ] })

    assert cruel[1][:working][:games] < 1.0, "the defender is unlikely to keep one"
    assert cruel[2][:working][:games] > cruel[1][:working][:games],
           "and his goalkeeper minds less, because the shots come to him"
  end

  test "the hardest fixture in the game is never a bonus, however many saves it brings" do
    keeper = regular(clean_sheets: 0.29).merge("last_season_saves_per_90" => 2.87,
                                               "last_season_expected_goals_conceded_per_90" => 1.49)
    rankings = [ ranking(1, position: "goalkeeper") ]

    ordinary = forecast(rankings, { 1 => keeper })
    cruel = forecast(rankings, { 1 => keeper }, fixtures: { 1 => [ fixture(5) ] })

    assert_operator cruel[1][:points], :<, ordinary[1][:points],
                    "a keeper at a leaky club away at the champions is worth less, not more"
  end

  test "a keeper is charged for the goals that go past him, not only for the clean sheet he misses" do
    rankings = [ ranking(1, position: "goalkeeper"), ranking(2, position: "goalkeeper") ]
    leaky = regular(clean_sheets: 0.25).merge("last_season_expected_goals_conceded_per_90" => 1.60)
    tight = regular(clean_sheets: 0.25).merge("last_season_expected_goals_conceded_per_90" => 0.70)

    result = forecast(rankings, { 1 => leaky, 2 => tight })

    assert_operator result[2][:points], :>, result[1][:points],
                    "two keepers who keep sheets alike are still told apart by what gets past them"
  end

  test "only whole pairs of goals are docked" do
    rankings = [ ranking(1, position: "defender") ]
    stats = { 1 => regular.merge("last_season_expected_goals_conceded_per_90" => 1.50) }
    free = { 1 => regular }

    charged = forecast(rankings, stats)
    uncharged = forecast(rankings, free)

    lost = uncharged[1][:points] - charged[1][:points]
    assert_operator lost, :<, 0.75, "charging for every second goal is not charging for half of them"
    assert_operator lost, :>, 0.35, "but a side shipping one and a half a game does pay for them"
  end

  test "a defender with no record of his own concedes at the rate of the club he has joined" do
    rankings = [ ranking(1, position: "defender", team_id: 1), ranking(2, position: "defender", team_id: 1),
                 ranking(3, position: "defender", team_id: 2), ranking(4, position: "defender", team_id: 2) ]
    stats = { 1 => regular.merge("last_season_expected_goals_conceded_per_90" => 0.70), 2 => regular,
              3 => regular.merge("last_season_expected_goals_conceded_per_90" => 1.60), 4 => regular }
    fixtures = { 1 => [ fixture ], 2 => [ fixture ] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_in_delta result[1][:points], result[2][:points], 0.01, "he is judged by the defence he plays in"
    assert_operator result[2][:points], :>, result[4][:points],
                    "and a tight defence is still worth more than a leaky one"
  end

  test "a promoted club with no record at all is judged as the worst defence in the league" do
    rankings = [ ranking(1, position: "goalkeeper", team_id: 1), ranking(2, position: "goalkeeper", team_id: 2),
                 ranking(3, position: "goalkeeper", team_id: 3) ]
    stats = { 1 => regular.merge("last_season_expected_goals_conceded_per_90" => 0.70),
              2 => regular.merge("last_season_expected_goals_conceded_per_90" => 1.60),
              3 => regular } # promoted: nobody at the club has a Premier League record
    fixtures = { 1 => [ fixture ], 2 => [ fixture ], 3 => [ fixture ] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_in_delta result[2][:points], result[3][:points], 0.01,
                    "an unknown defence is charged as the worst we know of, not as a perfect one"
    assert_operator result[1][:points], :>, result[3][:points],
                    "so promotion is no longer worth more than keeping goal behind the best defence in the game"
  end

  test "the goals that go past a defender are nothing to the man in front of him" do
    rankings = [ ranking(1, position: "midfielder"), ranking(2, position: "forward") ]
    stats = { 1 => regular.merge("last_season_expected_goals_conceded_per_90" => 1.60),
              2 => regular.merge("last_season_expected_goals_conceded_per_90" => 1.60) }
    clean = { 1 => regular, 2 => regular }

    conceding = forecast(rankings, stats)
    unbothered = forecast(rankings, clean)

    assert_equal unbothered[1][:points], conceding[1][:points], "FPL docks nobody in midfield for them"
    assert_equal unbothered[2][:points], conceding[2][:points], "nor anybody up front"
  end

  test "a kind fixture is worth most to the defender with the best record of clean sheets" do
    rankings = [ ranking(1, position: "defender"), ranking(2, position: "defender") ]
    stats = { 1 => regular(clean_sheets: 0.50), 2 => regular(clean_sheets: 0.10) }

    kind = forecast(rankings, stats, fixtures: { 1 => [ fixture(1) ] })

    assert kind[1][:working][:games] > kind[2][:working][:games],
           "a fixture can only be worth what the player would do with it"
  end

  test "a blank gameweek is nought points, and a double is worth about twice one game" do
    rankings = [ ranking(1, team_id: 1), ranking(2, team_id: 2), ranking(3, team_id: 3) ]
    stats = { 1 => regular, 2 => regular, 3 => regular }
    fixtures = { 1 => [ fixture ], 2 => [ fixture, fixture ], 3 => [] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_equal 0.0, result[3][:points], "no game, no points"
    assert_in_delta result[1][:points] * 2, result[2][:points], 0.05, "two games, two goes at it"
  end

  test "a fixture FPL has not rated still counts as a game" do
    rankings = [ ranking(1, team_id: 1), ranking(2, team_id: 2) ]
    stats = { 1 => regular, 2 => regular }
    fixtures = { 1 => [ { difficulty: nil, opponent: "Someone", home: true } ], 2 => [ fixture ] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_equal result[2][:points], result[1][:points],
                 "a gap in the data must not read as the team not playing"
    assert result[1][:points].positive?
  end

  test "a kind fixture is worth much more than a hard one, but the appearance points still anchor it" do
    rankings = [ ranking(1, team_id: 1), ranking(2, team_id: 2) ]
    stats = { 1 => regular, 2 => regular }
    fixtures = { 1 => [ fixture(2) ], 2 => [ fixture(5) ] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_operator result[1][:points], :>, result[2][:points] * 1.4, "the fixture is given a decisive say"
    assert_operator result[1][:points], :<, result[2][:points] * 2.0, "but two points for turning up cannot swing"
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

  # A field with a spread of records and of prices, so the crowd's ordering has a
  # shape to be read off and the cheapest tenth is a corner of it rather than most
  # of it. Players 1 and 2 are given identical records in the middle.
  def crowded_field(owned:, cost:)
    rankings = (1..12).map { |id| ranking(id, position: "forward") }
    stats = (3..12).to_h { |id| [ id, regular(xg: 0.05 * id, xgi: 0.08 * id, owned: 3.0, cost: 38.0 + 4 * id) ] }
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

  # Eight defenders on the four million pound floor with a spread of records, and
  # four dearer ones above them. Players 1 and 2 have the same thin record; the
  # game has piled into one of them and ignored the other.
  def cheap_field
    rankings = (1..12).map { |id| ranking(id, position: "defender") }
    stats = (3..8).to_h { |id| [ id, regular(xg: 0.02 * id, xgi: 0.04 * id, owned: 2.0, cost: 40.0) ] }
    stats.merge!((9..12).to_h { |id| [ id, regular(xg: 0.05 * id, xgi: 0.08 * id, owned: 5.0, cost: 40.0 + 4 * id) ] })
    stats[1] = regular(xg: 0.01, xgi: 0.02, owned: 25.0, cost: 40.0)
    stats[2] = regular(xg: 0.01, xgi: 0.02, owned: 0.3, cost: 40.0)
    [ rankings, stats ]
  end

  test "among the cheapest, the crowd still says which of them plays" do
    result = forecast(*cheap_field)

    assert result[1][:points] > result[2][:points],
           "the same record at the same price, but a quarter of the game owns one of them"
  end

  test "but backing a cheap player never carries him past what the dear ones are worth" do
    result = forecast(*cheap_field)

    assert result[1][:points] < result[12][:points],
           "the best the crowd can say of an enabler is that he is the best of the cheap"
  end

  test "the market leads, and a record may only nudge a player off it" do
    rankings, stats = crowded_field(owned: [ 60.0, 3.0 ], cost: [ 90.0, 55.0 ])
    stats[1] = regular(xg: 0.3, xgi: 0.45, owned: 60.0, cost: 90.0) # adored, ordinary record

    result = forecast(rankings, stats)

    assert result[1][:working][:crowd] > result[1][:working][:ours],
           "the crowd rates the hyped player above his own record"
    assert_operator result[1][:working][:perf_factor], :>=, 1 - ExpectedPoints::CLAMP_WIDTH,
                    "his ordinary record can pull him down, but only within the band"
    assert_in_delta result[1][:working][:crowd] * result[1][:working][:perf_factor],
                    result[1][:working][:ours], result[1][:working][:crowd], "the score sits on the market, nudged"
  end

  test "a wider band lets an ordinary record argue a hyped player further down" do
    rankings, stats = crowded_field(owned: [ 60.0, 3.0 ], cost: [ 90.0, 55.0 ])
    stats[1] = regular(xg: 0.3, xgi: 0.45, owned: 60.0, cost: 90.0) # adored, ordinary record

    led = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                              season_started: false, clamp_width: 0.05)
    freed = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                season_started: false, clamp_width: 0.4)

    assert freed[1][:points] < led[1][:points],
           "a wider band lets his ordinary record pull him back down toward it"
  end

  test "a dear, well-backed player the record has barely seen outranks a cheap one it knows well" do
    rankings, stats = crowded_field(owned: [ 12.0, 22.0 ], cost: [ 90.0, 55.0 ])
    stats[1] = regular(minutes: 700.0, xg: 0.30, xgi: 0.45, owned: 12.0, cost: 90.0) # injured last year, still dear
    stats[2] = regular(minutes: 3000.0, xg: 0.35, xgi: 0.55, owned: 22.0, cost: 55.0) # cheap, healthy, well-owned

    result = forecast(rankings, stats)

    assert result[1][:points] > result[2][:points],
           "what he costs remembers the season his thin record has forgotten"
  end

  test "a recent run counts for more as the season runs" do
    hot = { "season_minutes" => 3000.0, "expected_goals_per_90" => 0.30,
            "expected_goal_involvements_per_90" => 0.50, "clean_sheets_per_90" => 0.30,
            "selected_by_percent" => 5.0, "now_cost" => 60.0,
            "form" => 8.0, "points_per_game" => 4.0 } # in the middle of a hot streak

    early = ExpectedPoints.call([ ranking(1) ], stats: { 1 => hot }, fixtures_by_team: { 1 => [ fixture ] },
                                season_started: true, gameweeks_played: 2)
    late = ExpectedPoints.call([ ranking(1) ], stats: { 1 => hot }, fixtures_by_team: { 1 => [ fixture ] },
                               season_started: true, gameweeks_played: 30)

    assert late[1][:points] > early[1][:points],
           "his hot streak is let say more once there is a season of it to trust"
  end

  test "an established signing is held to half a match, and a longer horizon eases that" do
    rankings = [ ranking(1) ]
    stats = { 1 => regular(minutes: 3000.0) } # a full record, earned at his old club

    capped = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                season_started: false, movers: [ 1 ])
    eased = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                               season_started: false, movers: [ 1 ], new_club_minutes: 0.75)
    settled = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                 season_started: false, movers: [])

    assert_equal 45, capped[1][:working][:minutes], "a mover's record argues for half a match"
    assert eased[1][:points] > capped[1][:points], "a longer horizon eases the cap"
    assert eased[1][:points] < settled[1][:points], "but not all the way to a settled regular"
  end

  # Two signings with the same thin record at their old clubs. The only thing
  # separating them is how much of the game has already picked them.
  def two_signings(owned:)
    rankings = [ ranking(1), ranking(2) ]
    stats = { 1 => regular(minutes: 800.0, owned: owned.first),
              2 => regular(minutes: 800.0, owned: owned.last) }
    [ rankings, stats ]
  end

  test "a signing the game has picked is taken to have walked into the side" do
    rankings, stats = two_signings(owned: [ 20.0, 0.4 ])

    result = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                 season_started: false, movers: [ 1, 2 ])

    assert_equal 63, result[1][:working][:minutes], "a fifth of the game owning him settles it"
    assert_equal 30, result[2][:working][:minutes], "and nobody owning him leaves the caution in place"
  end

  test "backing can establish that a signing plays, never that he is any good" do
    rankings = [ ranking(1) ]
    stats = { 1 => regular(minutes: 3000.0, owned: 90.0) } # adored, and a full record elsewhere

    result = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                 season_started: false, movers: [ 1 ])

    assert_equal 63, result[1][:working][:minutes], "it stops at a regular's share, not a full match"
  end

  test "a settled player's minutes are his own business, however many own him" do
    rankings, stats = two_signings(owned: [ 40.0, 0.4 ])

    result = ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] },
                                 season_started: false, movers: [])

    assert_equal result[2][:working][:minutes], result[1][:working][:minutes],
                 "ownership only answers the question the new-club cap asks"
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
