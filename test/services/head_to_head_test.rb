require "test_helper"

class HeadToHeadTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @gameweek = gameweeks(:next_gw)
    Forecast.delete_all
  end

  def compare(horizon: "gameweek")
    HeadToHead.call(left: @salah, right: @palmer, gameweek: @gameweek, horizon: horizon)
  end

  def forecast(player, score, horizon: "gameweek", rank: 1)
    Forecast.create!(player: player, gameweek: @gameweek, horizon: horizon, score: score, rank: rank)
  end

  test "the better forecast wins" do
    forecast(@salah, 5.4)
    forecast(@palmer, 3.9, rank: 2)

    assert_equal @salah, compare.winner.player
    assert_equal @palmer, compare.loser.player
    assert_in_delta 1.5, compare.margin, 0.001
  end

  test "a gap too small to trust is not a winner" do
    forecast(@salah, 4.10)
    forecast(@palmer, 4.00, rank: 2)

    assert compare.tie?
    assert_nil compare.winner
  end

  # A manager holding two players and one transfer has to pick one of them, so
  # declining to answer sends him away to guess.
  test "a gap too small to trust still names a pick" do
    forecast(@salah, 4.10)
    forecast(@palmer, 4.00, rank: 2)

    assert compare.close?, "the gap is under the threshold"
    assert_equal @salah, compare.pick.player
    assert_equal @palmer, compare.runner_up.player
  end

  test "a comfortable pick is not called a close one" do
    forecast(@salah, 5.4)
    forecast(@palmer, 3.9, rank: 2)

    assert_not compare.close?
    assert_equal @salah, compare.pick.player
  end

  # There is nothing to pick between when there is nothing to pick from.
  test "no forecast for one of them means no pick at all" do
    forecast(@salah, 5.4)

    assert_not compare.forecast?
    assert_nil compare.pick
    assert_nil compare.runner_up
  end

  test "a player we cannot forecast is not a player we rate at nought" do
    forecast(@salah, 5.4)

    assert compare.tie?, "there is nothing to compare him with"
    assert_nil compare.winner
    assert_not compare.right.forecast?
  end

  test "a season total is read as the week it averages to before it is graded" do
    Gameweek.where.not(id: @gameweek.id).destroy_all
    forecast(@salah, 40.0, horizon: "season")
    forecast(@palmer, 38.0, horizon: "season", rank: 2)

    weekly = compare(horizon: "season")

    assert_equal 1, Gameweek.remaining_count
    assert_in_delta 2.0, weekly.margin, 0.001
    assert_equal "A+", weekly.left.grade, "40 points over one remaining week is a must-start"
  end

  test "a season margin shrinks with the weeks it is spread over" do
    forecast(@salah, 40.0, horizon: "season")
    forecast(@palmer, 38.0, horizon: "season", rank: 2)

    spread = compare(horizon: "season")

    assert_equal 2, Gameweek.remaining_count, "the next gameweek and the one after it"
    assert_in_delta 1.0, spread.margin, 0.001
  end

  test "who each of them is playing" do
    forecast(@salah, 5.4)
    forecast(@palmer, 3.9, rank: 2)
    Match.delete_all
    Match.create!(gameweek: @gameweek, home_team: teams(:liverpool), away_team: teams(:chelsea), fpl_id: 900)

    comparison = compare

    assert comparison.left.home?, "Salah's Liverpool are at home"
    assert_equal teams(:chelsea), comparison.left.opponent
    assert_equal teams(:liverpool), comparison.right.opponent
  end

  # Two free transfers is a choice between two moves, and a move is worth what
  # everybody in it is worth.
  test "a side of two is worth what both of them are worth" do
    forecast(@salah, 5.4)
    forecast(@palmer, 3.9, rank: 2)
    forecast(players(:goalkeeper), 4.0, rank: 3)

    pair = HeadToHead.call(left: [ @salah, @palmer ], right: players(:goalkeeper),
                           gameweek: @gameweek, horizon: "gameweek")

    assert_in_delta 9.3, pair.left.score, 0.001
    assert_in_delta 4.0, pair.right.score, 0.001
    assert_equal [ @salah, @palmer ], pair.left.players
  end

  # A pair that quietly drops a man and still shows a number is worse than a pair
  # with no number at all.
  test "a side is unforecast when anybody on it is" do
    forecast(@salah, 5.4)
    forecast(players(:goalkeeper), 4.0, rank: 3)

    pair = HeadToHead.call(left: [ @salah, @palmer ], right: players(:goalkeeper),
                           gameweek: @gameweek, horizon: "gameweek")

    assert_not pair.left.forecast?
    assert_nil pair.left.score
    assert_nil pair.pick
  end

  # A grade is a mark out of ten for one player over one week. Two players' points
  # added together would earn any pair an A.
  test "a side of two is not graded, and a side of one still is" do
    forecast(@salah, 5.4)
    forecast(@palmer, 3.9, rank: 2)
    forecast(players(:goalkeeper), 4.0, rank: 3)

    pair = HeadToHead.call(left: [ @salah, @palmer ], right: players(:goalkeeper),
                           gameweek: @gameweek, horizon: "gameweek")

    assert_nil pair.left.grade
    assert_nil pair.left.rank
    assert_not_nil pair.right.grade
  end

  # Two players carry two players' worth of error, so the gap they have to clear
  # before we will argue for one of them is wider.
  test "two sides of two have to be further apart before we back one" do
    forecast(@salah, 4.10)
    forecast(@palmer, 4.00, rank: 2)
    forecast(players(:goalkeeper), 4.05, rank: 3)
    forecast(players(:injured_player), 4.02, rank: 4)

    pair = HeadToHead.call(left: [ @salah, @palmer ], right: [ players(:goalkeeper), players(:injured_player) ],
                           gameweek: @gameweek, horizon: "gameweek")

    assert_in_delta 0.03, pair.margin, 0.001
    assert_in_delta HeadToHead::CLOSE * Math.sqrt(2), pair.close_enough, 0.001
    assert pair.close?
  end

  test "a side costs what everybody on it costs" do
    forecast(@salah, 5.4)
    forecast(@palmer, 3.9, rank: 2)
    Statistic.create!(player: @salah, gameweek: @gameweek, type: "now_cost", value: 145)
    Statistic.create!(player: @palmer, gameweek: @gameweek, type: "now_cost", value: 105)

    pair = HeadToHead.call(left: [ @salah, @palmer ], right: players(:goalkeeper),
                           gameweek: @gameweek, horizon: "gameweek")

    assert_equal 250, pair.left.cost
  end

  test "sides of different sizes are not a like-for-like question" do
    forecast(@salah, 5.4)
    forecast(@palmer, 3.9, rank: 2)

    assert_not HeadToHead.call(left: [ @salah, @palmer ], right: players(:goalkeeper),
                               gameweek: @gameweek, horizon: "gameweek").level?
    assert compare.level?
  end
end
