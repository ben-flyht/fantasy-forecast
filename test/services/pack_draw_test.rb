require "test_helper"

class PackDrawTest < ActiveSupport::TestCase
  setup do
    Statistic.destroy_all
    Forecast.destroy_all
    Player.destroy_all
    Gameweek.destroy_all
    Team.destroy_all

    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 3.days.from_now, is_next: true)
    @teams = 4.times.map { |i| Team.create!(fpl_id: 950 + i, code: 950 + i, name: "Club #{i}", short_name: "K#{i}") }
  end

  def build_pool(counts: { "goalkeeper" => 4, "defender" => 10, "midfielder" => 10, "forward" => 6 })
    id = 0
    counts.each do |position, count|
      count.times do |i|
        id += 1
        player = Player.create!(first_name: "P", last_name: "#{position}#{i}", short_name: "#{position[0, 3]}#{i}",
                                fpl_id: 7000 + id, code: 7000 + id, team: @teams[id % @teams.size], position: position)
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.4))
        Statistic.create!(player: player, gameweek: @gameweek, type: "now_cost", value: 45 + i)
      end
    end
  end

  test "the same seed draws the same pack" do
    build_pool

    first = PackDraw.call(gameweek: @gameweek, seed: 42)
    again = PackDraw.call(gameweek: @gameweek, seed: 42)

    assert_equal first.pairs.map { |pair| pair.cards.map(&:player_id) }, again.pairs.map { |pair| pair.cards.map(&:player_id) }
    assert_equal first.shiny_index, again.shiny_index
  end

  test "each pair is two neighbours in one position's rankings" do
    build_pool

    pack = PackDraw.call(gameweek: @gameweek, seed: 7)

    assert_equal Pack::SLOTS, pack.pairs.map(&:slot)
    pack.pairs.each do |pair|
      a, b = pair.cards
      assert_equal a.position, b.position
      assert_equal 1, (a.rank - b.rank).abs
      assert_includes Pack::OUTFIELD, a.position if pair.wildcard?
      assert_equal pair.slot, a.position unless pair.wildcard?
    end
  end

  test "no player turns up twice and exactly one pair is shiny" do
    build_pool

    20.times do |seed|
      pack = PackDraw.call(gameweek: @gameweek, seed: seed)
      ids = pack.pairs.flat_map { |pair| pair.cards.map(&:player_id) }

      assert_equal ids.uniq, ids
      assert_equal 1, pack.pairs.count(&:shiny?)
    end
  end

  test "the shiny pair, and so the captain, is always a midfielder or a forward" do
    build_pool

    100.times do |seed|
      shiny = PackDraw.call(gameweek: @gameweek, seed: seed).pairs.find(&:shiny?)

      assert_includes PackDraw::CAPTAINCY, shiny.cards.first.position, "seed #{seed}"
    end
  end

  test "a pack is fixed by the gameweek's forecasts, not by who is flagged or departed later" do
    build_pool
    before = PackDraw.call(gameweek: @gameweek, seed: 9).pairs.map { |pair| pair.cards.map(&:player_id) }

    Player.update_all(status: "i", departed: true, selectable: false)

    assert_equal before, PackDraw.call(gameweek: @gameweek, seed: 9).pairs.map { |pair| pair.cards.map(&:player_id) }
  end

  test "a player expected to add nothing to turning up is left out of the pack" do
    build_pool(counts: { "goalkeeper" => 2, "defender" => 4, "midfielder" => 4, "forward" => 2 })
    Forecast.joins(:player).where(players: { position: "forward" }).update_all(score: 1.0)

    assert_nil PackDraw.call(gameweek: @gameweek, seed: 1)
  end

  test "there is no pack without enough players to fill it" do
    build_pool(counts: { "goalkeeper" => 1, "defender" => 10, "midfielder" => 10, "forward" => 6 })

    assert_nil PackDraw.call(gameweek: @gameweek, seed: 1)
  end
end
