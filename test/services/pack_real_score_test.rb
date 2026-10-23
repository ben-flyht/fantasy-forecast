require "test_helper"

class PackRealScoreTest < ActiveSupport::TestCase
  setup do
    [ Performance, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    @gameweek = Gameweek.create!(fpl_id: 8, name: "Gameweek 8", start_time: 1.day.ago, is_current: true)
    @team = Team.create!(fpl_id: 991, code: 991, name: "Score City", short_name: "SCC")

    @cards = {
      gk: card("goalkeeper"), d1: card("defender"), d2: card("defender"), m1: card("midfielder"),
      m2: card("midfielder"), f1: card("forward"), w1: card("midfielder")
    }
    pairs = @cards.values.each_with_index.map do |held, index|
      Pack::Pair.new(slot: Pack::SLOTS[index], cards: [ held, held ], shiny: index == 3)
    end
    @hand = PackHand.parse(Pack.new(seed: 1, pairs: pairs), "aaaaaaa-26")
  end

  def card(position)
    @id = (@id || 0) + 1
    player = Player.create!(first_name: "P", last_name: "#{position}#{@id}", fpl_id: 5000 + @id, code: 5000 + @id,
                            team: @team, position: position)
    PickablePool::Candidate.new(player: player, rank: @id, cost: 50, expected_points: 3.0)
  end

  def scored(key, points, minutes: 90)
    player_id = @cards[key].player_id
    Performance.create!(player_id: player_id, gameweek: @gameweek, team: @team, gameweek_score: points)
    Statistic.create!(player_id: player_id, gameweek: @gameweek, type: "minutes", value: minutes)
  end

  test "live, it is the five so far with the captain counted twice" do
    { gk: 2, d1: 6, m1: 5, m2: 3, f1: 9, d2: 1, w1: 4 }.each { |key, points| scored(key, points) }

    result = PackRealScore.new(@gameweek).for(@hand)

    assert_equal 2 + 6 + 5 + 3 + 9 + 5, result.points
    assert_empty result.substitutions
    assert_not result.final?
  end

  test "once the gameweek is over, a starter who never played is replaced from the bench in order" do
    @gameweek.update!(is_finished: true)
    { gk: 2, d1: 6, m1: 5, f1: 9, d2: 1, w1: 4 }.each { |key, points| scored(key, points) }
    scored(:m2, 0, minutes: 0)

    result = PackRealScore.new(@gameweek).for(@hand)

    assert_equal [ [ @cards[:m2], @cards[:d2] ] ], result.substitutions
    assert_equal 2 + 6 + 5 + 9 + 1 + 5, result.points
  end

  test "a substitution that would leave no forward is skipped for the next on the bench" do
    @gameweek.update!(is_finished: true)
    { gk: 2, d1: 6, m1: 5, m2: 3, d2: 1, w1: 4 }.each { |key, points| scored(key, points) }
    scored(:f1, 0, minutes: 0)

    result = PackRealScore.new(@gameweek).for(@hand)

    assert_empty result.substitutions
    assert_equal 2 + 6 + 5 + 3 + 5, result.points
  end

  test "a captain who did not play is not doubled" do
    @gameweek.update!(is_finished: true)
    { gk: 2, d1: 6, m2: 3, f1: 9, d2: 1, w1: 4 }.each { |key, points| scored(key, points) }
    scored(:m1, 0, minutes: 0)

    result = PackRealScore.new(@gameweek).for(@hand)

    assert_equal 2 + 6 + 3 + 9 + 1, result.points
  end
end
