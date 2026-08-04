require "test_helper"

class StatisticTest < ActiveSupport::TestCase
  setup do
    @player = players(:midfielder)
    @gameweek = gameweeks(:next_gw)
  end

  def reading(type, value)
    now = Time.current
    { player_id: @player.id, gameweek_id: @gameweek.id, type: type, value: value,
      created_at: now, updated_at: now }
  end

  test "stores a reading it has not seen before" do
    assert_equal 1, Statistic.store([ reading("now_cost", 80.0) ])
    assert_equal 80.0, Statistic.find_by(player: @player, gameweek: @gameweek, type: "now_cost").value
  end

  test "leaves a reading that has not moved exactly as it was" do
    Statistic.store([ reading("now_cost", 80.0) ])
    stored = Statistic.find_by(player: @player, gameweek: @gameweek, type: "now_cost")

    travel 1.hour do
      assert_equal 0, Statistic.store([ reading("now_cost", 80.0) ]), "FPL republished the same figure"
    end

    assert_equal stored.updated_at, stored.reload.updated_at, "an unchanged row must not be rewritten"
  end

  test "a reading agrees with itself at the precision the column keeps" do
    Statistic.store([ reading("expected_goals_per_90", 0.336) ])

    assert_equal 0, Statistic.store([ reading("expected_goals_per_90", 0.336) ]),
                 "a rate rounded on the way in must not look like news every hour"
  end

  test "writes only what moved, out of a batch that mostly did not" do
    Statistic.store([ reading("now_cost", 80.0), reading("form", 5.0) ])

    assert_equal 1, Statistic.store([ reading("now_cost", 81.0), reading("form", 5.0) ])
    assert_equal 81.0, Statistic.find_by(player: @player, gameweek: @gameweek, type: "now_cost").value
  end

  test "the latest reading of each figure is the one that counts" do
    Statistic.store([ reading("form", 5.0) ])
    Statistic.create!(player: @player, gameweek: gameweeks(:finished), type: "form", value: 2.0)

    latest = Statistic.where(player_id: @player.id, type: "form").latest_by_player

    assert_equal 5.0, latest[@player.id]["form"], "the newest gameweek wins, not the last row read"
  end
end
