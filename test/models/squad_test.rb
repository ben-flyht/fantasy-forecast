require "test_helper"

class SquadTest < ActiveSupport::TestCase
  setup do
    Squad.destroy_all
    @gameweek = gameweeks(:next_gw)
  end

  # Positions and scores are what these tests are about, so the players are only
  # here to be pointed at.
  def pick(position, points, starting: true, cost: 50, id: nil)
    { "player_id" => id || rand(1_000_000), "position" => position, "team_id" => 1,
      "cost" => cost, "expected_points" => points, "starting" => starting }
  end

  def squad_of(picks, horizon: "gameweek")
    Squad.create!(gameweek: @gameweek, horizon: horizon, formation: "4-4-2",
                  cost: 985, expected_points: 60, picks: picks)
  end

  test "the armband goes on the best player who is starting" do
    squad = squad_of([ pick("midfielder", 9.0), pick("forward", 4.0),
                       pick("forward", 12.0, starting: false) ])

    assert_equal 9.0, squad.captain["expected_points"]
  end

  # FPL lists the reserve keeper first, and he is not in the queue with the others:
  # he is the only man who can come on for the one man in goal.
  test "the bench leads with the keeper, then the outfield in the order they come on" do
    squad = squad_of([ pick("midfielder", 8.0),
                       pick("defender", 3.0, starting: false),
                       pick("goalkeeper", 2.0, starting: false),
                       pick("forward", 5.0, starting: false) ])

    assert_equal %w[goalkeeper forward defender], squad.bench.map { |p| p["position"] }
  end

  test "a starting eleven is read out best first, position by position" do
    squad = squad_of([ pick("defender", 3.0), pick("defender", 7.0), pick("defender", 5.0),
                       pick("forward", 9.0) ])

    assert_equal [ 7.0, 5.0, 3.0 ], squad.starters_in("defender").map { |p| p["expected_points"] }
    assert_empty squad.starters_in("goalkeeper")
  end

  test "what is left of the budget is what was not spent" do
    squad = squad_of([ pick("forward", 5.0) ])

    assert_equal SquadOptimiser::BUDGET - squad.cost, squad.banked
  end

  # A season score spans every week that remains, so it is averaged back to one before
  # it meets the grade bands. Without that a season squad would be all A pluses and a
  # weekly one all Ds, from the same players.
  test "a season pick is graded on the same scale a weekly one is" do
    weekly = squad_of([ pick("forward", 5.0) ]).ranking_for(pick("forward", 5.0))
    seasonal = squad_of([ pick("forward", 5.0 * Gameweek.remaining_count) ], horizon: "season")

    assert_equal weekly.grade, seasonal.ranking_for(pick("forward", 5.0 * Gameweek.remaining_count)).grade
  end

  test "a pick is described the way the rankings describe a player, so one row draws both" do
    squad = squad_of([ pick("midfielder", 6.0, cost: 75) ])
    ranking = squad.ranking_for(squad.picks.first)

    assert_equal "midfielder", ranking.position
    assert_equal 6.0, ranking.score
    assert_not_nil ranking.grade
    assert_not_nil ranking.tier
  end

  test "it knows which horizon it was picked for" do
    assert_predicate squad_of([ pick("forward", 5.0) ], horizon: "season"), :season?
    assert_not_predicate squad_of([ pick("forward", 5.0) ]), :season?
  end
end
