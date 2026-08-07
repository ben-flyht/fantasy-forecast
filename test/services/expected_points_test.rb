require "test_helper"

class ExpectedPointsTest < ActiveSupport::TestCase
  def ranking(player_id, position: "midfielder", team_id: 1)
    ConsensusRanking::Ranking.new(player_id: player_id, position: position, team_id: team_id, score: 100)
  end

  def fixture(difficulty = 3, opponent: "Someone", home: true)
    { difficulty: difficulty, opponent: opponent, home: home }
  end

  # A regular starter with a decent record behind him.
  #
  # xa is what his passing was expected to be worth per game, and conceded is what
  # his side is expected to let in: 1.20 is a middling defence, which keeps about a
  # third of its sheets clean. Between them they are what an assist and a clean
  # sheet are now read from. See ExpectedPoints#assist_points.
  def regular(minutes: 3000.0, xg: 0.30, xgi: 0.50, xa: 0.20, conceded: 1.20,
              owned: 5.0, cost: 60.0)
    {
      "last_season_minutes" => minutes, "last_season_expected_goals_per_90" => xg,
      "last_season_expected_goal_involvements_per_90" => xgi,
      "last_season_expected_assists_per_90" => xa,
      "last_season_expected_goals_conceded_per_90" => conceded,
      "selected_by_percent" => owned, "now_cost" => cost
    }
  end

  # A player with nothing of his own to say about conceding, so his club answers
  # for him. Both the clean sheet and the goals past him read from that one figure.
  def newcomer
    regular.except("last_season_expected_goals_conceded_per_90")
  end

  # What 0.20 expected assists a game is worth to a player in this position,
  # measured against the same player creating nothing at all.
  def assist_worth(position)
    rankings = [ ranking(1, position: position) ]
    creating = forecast(rankings, { 1 => regular(xa: 0.20) })[1][:working][:per_90]
    barren = forecast(rankings, { 1 => regular(xa: 0.0) })[1][:working][:per_90]
    creating - barren
  end

  def forecast(rankings, stats, fixtures: { 1 => [ fixture ] }, managers: nil, movers: [])
    ExpectedPoints.call(rankings, stats: stats, fixtures_by_team: fixtures,
                       season_started: false, managers: managers, movers: movers)
  end

  test "expected points is minutes, times what he is worth per 90, times the games ahead" do
    result = forecast([ ranking(1) ], { 1 => regular })

    # 90 minutes of a 0.3 xG, 0.2 xA midfielder on a level fixture: two points for
    # turning up, plus what he is worth on top. A full season of minutes behind
    # him, so nothing is held back for doubt.
    assert_in_delta 4.58, result[1][:points], 0.1
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
    stats = { 1 => regular(xa: 0.20), 2 => regular(xa: 0.21) }

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
    # paid for nothing but being there: no goals, no assists, nothing to keep out
    stats = { 1 => regular(xg: 0.0, xgi: 0.0, xa: 0.0, conceded: 0.0) }

    kind = forecast(rankings, stats, fixtures: { 1 => [ fixture(1) ] })
    cruel = forecast(rankings, stats, fixtures: { 1 => [ fixture(5) ] })

    assert_equal kind[1][:points], cruel[1][:points],
                 "no opponent can change what a man gets for being on the pitch"
  end

  test "a hard afternoon costs a defender his clean sheet and brings a goalkeeper saves" do
    rankings = [ ranking(1, position: "defender"), ranking(2, position: "goalkeeper") ]
    # 1.05 expected against is a 0.35 chance of the sheet staying clean
    stats = { 1 => regular(conceded: 1.05),
              2 => regular(conceded: 1.05).merge("last_season_saves_per_90" => 3.0) }

    cruel = forecast(rankings, stats, fixtures: { 1 => [ fixture(5) ] })

    assert cruel[1][:working][:games] < 1.0, "the defender is unlikely to keep one"
    assert cruel[2][:working][:games] > cruel[1][:working][:games],
           "and his goalkeeper minds less, because the shots come to him"
  end

  test "the hardest fixture in the game is never a bonus, however many saves it brings" do
    keeper = regular(conceded: 1.49).merge("last_season_saves_per_90" => 2.87)
    rankings = [ ranking(1, position: "goalkeeper") ]

    ordinary = forecast(rankings, { 1 => keeper })
    cruel = forecast(rankings, { 1 => keeper }, fixtures: { 1 => [ fixture(5) ] })

    assert_operator cruel[1][:points], :<, ordinary[1][:points],
                    "a keeper at a leaky club away at the champions is worth less, not more"
  end

  # Both halves of the charge read from the same figure now that a clean sheet is
  # the chance of one rather than the share he happened to keep, so a leaky club
  # costs its keeper twice: the sheet he will not keep, and the goals themselves.
  test "a keeper at a leaky club is charged for the goals as well as the clean sheet" do
    rankings = [ ranking(1, position: "goalkeeper"), ranking(2, position: "goalkeeper") ]
    leaky = regular(conceded: 1.60)
    tight = regular(conceded: 0.70)

    result = forecast(rankings, { 1 => leaky, 2 => tight })

    assert_operator result[2][:points], :>, result[1][:points],
                    "the tighter defence is worth more to the man behind it, on both counts"
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
    tight = (1..3).map { |id| ranking(id, position: "defender", team_id: 1) }
    leaky = (5..7).map { |id| ranking(id, position: "defender", team_id: 2) }
    newcomers = [ ranking(4, position: "defender", team_id: 1), ranking(8, position: "defender", team_id: 2) ]
    stats = (1..3).index_with { regular.merge("last_season_expected_goals_conceded_per_90" => 0.70) }
                  .merge((5..7).index_with { regular.merge("last_season_expected_goals_conceded_per_90" => 1.60) })
                  .merge(4 => newcomer, 8 => newcomer)
    fixtures = { 1 => [ fixture ], 2 => [ fixture ] }

    result = forecast(tight + leaky + newcomers, stats, fixtures: fixtures)

    assert_in_delta result[1][:points], result[4][:points], 0.01, "he is judged by the defence he plays in"
    assert_operator result[4][:points], :>, result[8][:points],
                    "and a tight defence is still worth more than a leaky one"
  end

  # Ten actions in a match is a bar, not a rate, and the difference is the whole
  # point: the same three extra actions a game are worth almost nothing to a
  # player who will not reach it, a great deal to one it carries over the line,
  # and little again to one already clearing it most weeks.
  test "defensive contribution is how often he clears the bar, not what he averages" do
    actions = [ 3.0, 6.0, 9.0, 12.0, 15.0 ]
    rankings = actions.each_index.map { |i| ranking(i + 1, position: "defender") }
    stats = actions.each_with_index.to_h { |rate, i| [ i + 1, regular.merge("last_season_defensive_contribution_per_90" => rate) ] }

    result = forecast(rankings, stats)
    steps = (1..4).map { |i| result[i + 1][:points] - result[i][:points] }

    assert_operator steps[0], :<, steps[1], "out of reach is out of reach, however close he gets"
    assert_operator steps[3], :<, steps[2], "and there is little left to win once he clears it most weeks"
    assert_operator steps[1], :>, 0.3, "while over the line itself is worth real points"
  end

  test "a bar is cleared over the minutes he plays, not scaled down after the fact" do
    rankings = [ ranking(1, position: "defender"), ranking(2, position: "defender") ]
    full = regular(minutes: 3000.0).merge("last_season_defensive_contribution_per_90" => 9.0)
    half = regular(minutes: 1200.0).merge("last_season_defensive_contribution_per_90" => 9.0)

    result = forecast(rankings, { 1 => full, 2 => half })
    ratio = result[2][:points] / result[1][:points]

    assert_operator ratio, :<, result[2][:working][:minutes] / result[1][:working][:minutes].to_f,
                    "half a match is far less than half a chance of ten actions"
  end

  test "a goalkeeper is not paid for defending, however much of it he does" do
    rankings = [ ranking(1, position: "goalkeeper"), ranking(2, position: "goalkeeper") ]
    stats = { 1 => regular.merge("last_season_defensive_contribution_per_90" => 12.0), 2 => regular }

    result = forecast(rankings, stats)

    assert_in_delta result[1][:points], result[2][:points], 0.01, "FPL pays a keeper nothing for it"
  end

  # Promoted sides concede more than anybody, so an unknown defence is charged the
  # worst in the league. They do not defend any more than anybody, so the same
  # reasoning must not be carried across to this.
  test "a club nobody has a record for defends like an ordinary side, not like the busiest" do
    clubs = { 1 => 11.0, 2 => 8.0, 3 => 5.0 }
    rankings = clubs.keys.flat_map { |team| (1..3).map { |n| ranking(team * 10 + n, position: "defender", team_id: team) } }
    promoted = ranking(99, position: "defender", team_id: 4)
    stats = rankings.to_h do |member|
      [ member.player_id, regular.merge("last_season_defensive_contribution_per_90" => clubs[member.team_id]) ]
    end.merge(99 => regular)
    fixtures = (1..4).index_with { [ fixture ] }

    result = forecast(rankings + [ promoted ], stats, fixtures: fixtures)

    assert_operator result[99][:points], :<, result[11][:points],
                    "a club we have never seen must not inherit the best defensive record in the league"
    assert_operator result[99][:points], :>, result[31][:points], "nor the worst"
    assert_in_delta result[21][:points], result[99][:points], 0.01, "it defends like the middle of the league"
  end

  test "one man's record does not become his club's" do
    rankings = (1..4).map { |id| ranking(id, position: "defender", team_id: 1) } +
               [ ranking(5, position: "defender", team_id: 2), ranking(6, position: "defender", team_id: 2) ]
    stats = (1..4).index_with { regular.merge("last_season_expected_goals_conceded_per_90" => 1.60) }
                  .merge(5 => regular.merge("last_season_expected_goals_conceded_per_90" => 0.70), 6 => regular)
    fixtures = { 1 => [ fixture ], 2 => [ fixture ] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_operator result[6][:points], :<, result[5][:points],
                    "one team-mate with a record is not a club's record, so his club is judged as unknown"
  end

  test "a promoted club with no record at all is judged as the worst defence in the league" do
    tight = (1..3).map { |id| ranking(id, position: "goalkeeper", team_id: 1) }
    leaky = (4..6).map { |id| ranking(id, position: "goalkeeper", team_id: 2) }
    # Three at the promoted club too, so each squad splits its one place the same
    # way and the comparison is of defences rather than of squad sizes.
    promoted = (7..9).map { |id| ranking(id, position: "goalkeeper", team_id: 3) }
    stats = (1..3).index_with { regular.merge("last_season_expected_goals_conceded_per_90" => 0.70) }
                  .merge((4..6).index_with { regular.merge("last_season_expected_goals_conceded_per_90" => 1.60) })
                  .merge((7..9).index_with { newcomer }) # promoted: no Premier League record at the club
    fixtures = { 1 => [ fixture ], 2 => [ fixture ], 3 => [ fixture ] }

    result = forecast(tight + leaky + promoted, stats, fixtures: fixtures)

    assert_in_delta result[4][:points], result[7][:points], 0.01,
                    "an unknown defence is charged as the worst we know of, not as a perfect one"
    assert_operator result[1][:points], :>, result[7][:points],
                    "so promotion is no longer worth more than keeping goal behind the best defence in the game"
  end

  # FPL docks only a goalkeeper and a defender for the goals themselves, but it
  # pays a midfielder a point for the clean sheet, so what a club concedes reaches
  # him too. It reaches him for a quarter of what it costs the man behind him, and
  # for none of what the goals cost on top of that.
  test "what a club concedes is nothing to the man up front, and only a clean sheet to the one in midfield" do
    rankings = [ ranking(1, position: "forward"), ranking(2, position: "midfielder"),
                 ranking(3, position: "defender") ]
    leaky = regular(conceded: 1.60)
    tight = regular(conceded: 1.20)

    conceding = forecast(rankings, { 1 => leaky, 2 => leaky, 3 => leaky })
    unbothered = forecast(rankings, { 1 => tight, 2 => tight, 3 => tight })

    assert_equal unbothered[1][:points], conceding[1][:points],
                 "a forward is paid for none of it, neither the sheet nor the goals"

    in_midfield = unbothered[2][:points] - conceding[2][:points]
    at_the_back = unbothered[3][:points] - conceding[3][:points]

    assert_operator in_midfield, :>, 0, "a midfielder still loses the clean sheet, worth one to him"
    assert_operator at_the_back, :>, in_midfield * 4,
                    "and a defender loses four times that, plus the goals FPL docks him for"
  end

  # Two identical defences, one of which shut teams out more often than its
  # football deserved. Last season's luck must not be sold as next season's rate.
  test "a clean sheet is the chance of keeping one, not the share he happened to keep" do
    rankings = [ ranking(1, position: "defender"), ranking(2, position: "defender") ]
    lucky = regular(conceded: 1.20).merge("last_season_clean_sheets_per_90" => 0.60)
    ordinary = regular(conceded: 1.20).merge("last_season_clean_sheets_per_90" => 0.20)

    result = forecast(rankings, { 1 => lucky, 2 => ordinary })

    assert_in_delta result[1][:points], result[2][:points], 0.001,
                    "what a side actually kept is a record of its luck as much as of its defending"
  end

  test "a defence nobody can measure keeps no clean sheets rather than every one" do
    rankings = [ ranking(1, position: "defender", team_id: 1),
                 ranking(2, position: "defender", team_id: 2) ]
    best_in_the_league = regular(conceded: 0.40)

    result = forecast(rankings, { 1 => newcomer, 2 => best_in_the_league },
                      fixtures: { 1 => [ fixture ], 2 => [ fixture ] })

    assert_operator result[1][:points], :<, result[2][:points],
                    "nought expected against is no opinion, not a certainty of keeping it out"
  end

  # FPL pays for the penalty won, the deflection and the rebound, none of which an
  # expected assist counts, so the expected figure is lifted to what the league is
  # actually awarded. A forward is paid most for it: he is the man fouled for the
  # penalty and the man whose saved shot falls to somebody else.
  test "an expected assist is lifted to what FPL actually awards, hardest up front" do
    in_midfield = assist_worth("midfielder")
    up_front = assist_worth("forward")

    assert_in_delta 0.78, in_midfield, 0.01, "three points an assist, lifted a third again"
    assert_in_delta 1.35, up_front, 0.01, "and more than twice over for a forward"
    assert_operator up_front, :>, in_midfield,
                    "he wins the penalty and his saved shot falls to somebody else"
  end

  test "creating more is worth more, and nothing is paid for creating nothing" do
    rankings = [ ranking(1), ranking(2), ranking(3) ]
    stats = { 1 => regular(xa: 0.30), 2 => regular(xa: 0.10), 3 => regular(xa: 0.0) }

    result = forecast(rankings, stats)

    assert_operator result[1][:points], :>, result[2][:points]
    assert_operator result[2][:points], :>, result[3][:points]
  end

  # Three saves in a match is a point, and five is still a point: FPL counts them
  # per match, pays for each whole three and throws the remainder away at full time.
  test "saves are paid in whole threes, not by the fraction" do
    rankings = [ ranking(1, position: "goalkeeper") ]
    busy = regular.merge("last_season_saves_per_90" => 3.0)

    worth = forecast(rankings, { 1 => busy })[1][:points] -
            forecast(rankings, { 1 => regular })[1][:points]

    assert_operator worth, :<, 1.0,
                    "three saves a game is not a point a game, whatever the arithmetic wants"
    assert_in_delta 0.66, worth, 0.05,
                    "he reaches three in 58 matches of a hundred, and six in eight more"
  end

  # The doubt is there to stop a rate built from a cameo topping the table. Once a
  # man has played a season it has nothing left to ask, and taking a fixed share off
  # him for ever took most from whoever scored most.
  test "past a regular's season the record stops being shrunk for doubt" do
    rankings = [ ranking(1), ranking(2), ranking(3) ]
    stats = { 1 => regular(minutes: 2400.0), 2 => regular(minutes: 3400.0),
              3 => regular(minutes: 900.0) }

    result = forecast(rankings, stats)

    assert_in_delta result[1][:working][:per_90], result[2][:working][:per_90], 0.001,
                    "a season and a half is no more proof than a season"
    assert_operator result[3][:working][:per_90], :<, result[1][:working][:per_90],
                    "but a third of one is still short of it"
  end

  test "a kind fixture is worth most to the defender with the best record of clean sheets" do
    rankings = [ ranking(1, position: "defender"), ranking(2, position: "defender") ]
    # 0.69 expected against keeps half his sheets clean; 2.30 keeps a tenth
    stats = { 1 => regular(conceded: 0.69), 2 => regular(conceded: 2.30) }

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

  test "two fixtures of the same difficulty are worth exactly twice one of them" do
    one = forecast([ ranking(1) ], { 1 => regular }, fixtures: { 1 => [ fixture(3) ] })
    two = forecast([ ranking(1) ], { 1 => regular }, fixtures: { 1 => [ fixture(3), fixture(3) ] })

    assert_in_delta 2.0, two[1][:working][:games], 0.001
    assert_in_delta one[1][:points] * 2, two[1][:points], 0.001
  end

  test "a kinder fixture is still worth more than a cruel one alongside it" do
    result = forecast([ ranking(1) ], { 1 => regular }, fixtures: { 1 => [ fixture(2), fixture(5) ] })
    kind = forecast([ ranking(1) ], { 1 => regular }, fixtures: { 1 => [ fixture(2), fixture(2) ] })

    assert result[1][:points] < kind[1][:points],
           "difficulty must still be read per fixture, not taken from the first one"
  end

  # A position spread across the price range, dearer players being better, since
  # what a player's backing means depends on how cheap he is and there has to be
  # something to tell the two ends apart. Price, ownership, and what he does.
  def priced_field
    # 1 and 4 keep the same record on purpose: they differ only in what they cost
    # and who has bought them, which is what the crowd is being asked about.
    spec = { 1 => [ 45.0, 12.0, 0.35 ], 2 => [ 45.0, 0.2, 0.30 ], 3 => [ 50.0, 6.0, 0.45 ],
             4 => [ 50.0, 0.2, 0.35 ], 5 => [ 55.0, 4.0, 0.55 ], 6 => [ 60.0, 3.0, 0.65 ],
             7 => [ 70.0, 8.0, 0.80 ] }
    rankings = spec.keys.map { |id| ranking(id) }
    stats = spec.to_h { |id, (cost, owned, xg)| [ id, regular(cost: cost, owned: owned, xg: xg) ] }
    [ rankings, stats ]
  end

  def model_for(rankings, stats)
    ExpectedPoints.new(rankings, stats: stats, fixtures_by_team: { 1 => [ fixture ] }, season_started: false)
  end

  def order_of(result, rankings)
    rankings.sort_by { |r| -result[r.player_id][:points] }.each_with_index.to_h { |r, i| [ r.player_id, i + 1 ] }
  end

  # The reason this is measured in money. A share of a tied field is not a line,
  # it is a cliff somebody is always standing on, and one player's overnight
  # reprice used to shift a whole tier across it at once.
  test "one player being repriced does not move everybody else" do
    rankings, stats = priced_field
    before = order_of(forecast(rankings, stats), rankings)

    repriced = stats.merge(4 => stats[4].merge("now_cost" => 45.0)) # 5.0m to 4.5m, owned by 0.2%
    after = order_of(forecast(rankings, repriced), rankings)

    moved = (before.keys - [ 4 ]).map { |id| (before[id] - after[id]).abs }
    assert_operator moved.max, :<=, 1,
                    "an unowned player getting cheaper says nothing about anybody else"
  end

  test "players sharing the floor price do not push each other up the scale" do
    rankings, stats = priced_field
    alone = forecast(rankings, stats)

    # Twenty more on the floor, owned by nobody and with nothing on record, so
    # they add no backing and no figure to any curve. Under a rank share they
    # would still have moved every line in the position.
    crowd = (100..119).map { |id| ranking(id) }
    padded = stats.merge((100..119).index_with { { "now_cost" => 45.0, "selected_by_percent" => 0.0 } })
    packed = forecast(rankings + crowd, padded)

    rankings.each do |r|
      assert_in_delta alone[r.player_id][:points], packed[r.player_id][:points], 0.001,
                      "#{r.player_id} moved because other players happen to share a price"
    end
  end

  test "a cheap player the game has bought outranks a dear one nobody has" do
    rankings, stats = priced_field

    result = forecast(rankings, stats)

    assert_operator result[1][:points], :>, result[4][:points],
                    "4.5m and owned by a tenth of the game beats 5.0m and owned by nobody"
  end

  # The cheapest man in a position is a complete bargain, half a million above him
  # is half a bargain, and a million above him is not a bargain at all.
  test "being a bargain fades with price rather than stopping at a line" do
    rankings, stats = priced_field
    model = model_for(rankings, stats)
    floor, half_a_step, a_step = rankings.values_at(0, 2, 4) # 4.5m, 5.0m, 5.5m

    assert_in_delta 1.0, model.send(:cheapness, floor), 0.001
    assert_in_delta 0.5, model.send(:cheapness, half_a_step), 0.001
    assert_in_delta 0.0, model.send(:cheapness, a_step), 0.001
  end

  # Two keepers at one club, and what each of them brings to the argument over
  # who plays: minutes on record, and how much of the game has bought him.
  def keepers(first:, second:)
    rankings = [ ranking(1, position: "goalkeeper", team_id: 1),
                 ranking(2, position: "goalkeeper", team_id: 1) ]
    stats = { 1 => regular(**first), 2 => regular(**second) }
    forecast(rankings, stats)
  end

  # What share of his club's one place a keeper was given, read back out of the
  # answer: minutes are the figure the model says it multiplied by.
  def share_of(result, player_id)
    result[player_id][:working][:minutes] / ExpectedPoints::FULL_MATCH
  end

  test "a club's keepers share the one place it has to give" do
    result = keepers(first: { minutes: 3000.0, owned: 20.0 }, second: { minutes: 1500.0, owned: 15.0 })

    assert_in_delta 1.0, share_of(result, 1) + share_of(result, 2), 0.02,
                    "two keepers at a club cannot both play every week"
  end

  test "a club nobody owns is left to its record" do
    result = keepers(first: { minutes: 3000.0, owned: 0.2 }, second: { minutes: 200.0, owned: 0.1 })

    assert_operator share_of(result, 1), :>, 0.9,
                    "a first choice is not marked down for having a deputy nobody has picked"
  end

  test "a club the game is split over is decided by the split, not by last season" do
    result = keepers(first: { minutes: 3000.0, owned: 1.0 }, second: { minutes: 600.0, owned: 25.0 })

    assert_operator share_of(result, 2), :>, share_of(result, 1),
                    "a quarter of the game backing the newcomer outweighs the incumbent's old minutes"
  end

  test "a club with no record for anybody falls back to what the crowd has backed" do
    promoted = { "selected_by_percent" => 8.0, "now_cost" => 45.0 }
    reserve = { "selected_by_percent" => 0.5, "now_cost" => 40.0 }
    # Keepers elsewhere with records, at both ends of the price range, so each
    # price bracket has somebody measurable in it. A bracket of men who cannot be
    # measured has no curve to read a standing off at all.
    elsewhere = (3..5).map { |id| ranking(id, position: "goalkeeper", team_id: id) }
    rankings = [ ranking(1, position: "goalkeeper", team_id: 1),
                 ranking(2, position: "goalkeeper", team_id: 1) ] + elsewhere
    stats = { 1 => promoted, 2 => reserve, 3 => regular(cost: 40.0), 4 => regular(cost: 45.0),
              5 => regular(cost: 50.0) }
    fixtures = (1..5).index_with { [ fixture ] }

    result = forecast(rankings, stats, fixtures: fixtures)

    assert_in_delta 1.0, share_of(result, 1) + share_of(result, 2), 0.02,
                    "a promoted club still puts somebody in goal, so its place is shared out rather than left empty"
    assert_operator share_of(result, 1), :>, share_of(result, 2),
                    "and the crowd says which of them it is"
  end

  test "many times a deputy's minutes is a first choice, not a proportionally better one" do
    result = keepers(first: { minutes: 2900.0, owned: 4.0 }, second: { minutes: 1000.0, owned: 1.0 })

    assert_operator share_of(result, 1), :>, 0.85,
                    "played three times as much means he is the goalkeeper, not that he is three times as likely"
  end

  # The crowd is allowed to say a keeper has taken the shirt, because it knows
  # about a signing or a demotion that last season's minutes cannot. What it may
  # not do is settle the question on its own while the record still disagrees.
  test "backing cannot hand a deputy the whole place over a record that disagrees" do
    result = keepers(first: { minutes: 3200.0, owned: 3.0 }, second: { minutes: 0.0, owned: 12.0 })

    assert_operator share_of(result, 2), :<, 0.6,
                    "four times the backing does not make a man who has never played a certain starter"
    assert_operator share_of(result, 2), :>, 0.3,
                    "but it is heard, because it knows about signings and demotions that a record cannot"
  end

  # The check that found the bug this rule exists for, kept because it will find
  # the next one: a keeper's place cannot be created or destroyed, only shared.
  test "no club fields more or less than one goalkeeper" do
    squads = (1..4).flat_map do |club|
      (1..3).map { |slot| ranking(club * 10 + slot, position: "goalkeeper", team_id: club) }
    end
    stats = squads.each_with_index.to_h do |keeper, index|
      [ keeper.player_id, regular(minutes: [ 3000.0, 900.0, 0.0 ][index % 3], owned: [ 15.0, 2.0, 0.1 ][index % 3]) ]
    end
    fixtures = (1..4).index_with { [ fixture ] }

    result = forecast(squads, stats, fixtures: fixtures)

    squads.group_by(&:team_id).each do |club, keepers|
      shared = keepers.sum { |keeper| share_of(result, keeper.player_id) }
      assert_in_delta 1.0, shared, 0.02, "club #{club} is fielding #{shared.round(2)} goalkeepers"
    end
  end

  test "an outfield player's minutes are untouched by any of this" do
    result = forecast([ ranking(1, position: "defender"), ranking(2, position: "defender") ],
                      { 1 => regular(minutes: 3000.0), 2 => regular(minutes: 3000.0) })

    assert_equal 90, result[1][:working][:minutes]
    assert_in_delta result[1][:points], result[2][:points], 0.001,
                    "ten outfield players at a club do not share one shirt between them"
  end

  test "the working stores the figures it multiplied, not sentences about them" do
    result = forecast([ ranking(1, team_id: 1) ], { 1 => regular })
    working = result[1][:working]

    assert_equal 90, working[:minutes]
    assert_in_delta 4.58, working[:per_90], 0.2
    assert_equal 1.0, working[:games], "one ordinary fixture"
    assert_equal [ { name: "Someone", home: true, difficulty: 3 } ], working[:opponents]
    assert working.values.none? { |value| value.is_a?(String) }, "wording belongs in the view"
  end
end
