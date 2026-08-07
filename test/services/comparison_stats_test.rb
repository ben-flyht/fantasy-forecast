require "test_helper"

class ComparisonStatsTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @gameweek = gameweeks(:next_gw)
    Statistic.delete_all
  end

  def reading(player, type, value)
    Statistic.create!(player: player, gameweek: @gameweek, type: type, value: value)
  end

  def stats = ComparisonStats.call(left: @salah, right: @palmer)

  def row(label)
    stats.flat_map(&:rows).find { |r| r.label == label }
  end

  # A keeper's saves and a forward's goals are both in the table, and neither
  # leaves an empty line on the other man's page.
  test "a figure neither of them has is not a row" do
    reading(@salah, "season_points", 120)

    assert_equal [ "Total points" ], stats.flat_map(&:rows).map(&:label)
  end

  test "a figure only one of them has is still worth a row" do
    reading(@salah, "saves_per_90", 3.2)

    assert_equal "3.20", row("Saves").left
    assert_equal "—", row("Saves").right
  end

  test "more is better, so the bigger number leads" do
    reading(@salah, "season_points", 120)
    reading(@palmer, "season_points", 90)

    assert_equal :left, row("Total points").leader
  end

  # Conceding fewer expected goals is the good end of that figure, and so is
  # costing less.
  test "for some figures less is better" do
    reading(@salah, "expected_goals_conceded_per_90", 1.4)
    reading(@palmer, "expected_goals_conceded_per_90", 0.8)
    reading(@salah, "now_cost", 145)
    reading(@palmer, "now_cost", 60)

    assert_equal :right, row("Expected goals conceded").leader
    assert_equal :right, row("Price").leader
    assert_equal "£14.5m", row("Price").left
  end

  # Ownership is a fact about a player, not a mark out of ten, so neither side of
  # it is lit.
  test "a figure that is a fact rather than a merit favours nobody" do
    reading(@salah, "selected_by_percent", 55.0)
    reading(@palmer, "selected_by_percent", 12.0)

    assert_nil row("Owned by").leader
    assert_equal "55.0%", row("Owned by").left
  end

  test "two equal figures light neither side" do
    reading(@salah, "form", 4.0)
    reading(@palmer, "form", 4.0)

    assert_nil row("Form").leader
  end

  # FPL numbers set-piece takers from the front, so first is best.
  test "a set piece order reads as a place, and first is best" do
    reading(@salah, "penalties_order", 1)
    reading(@palmer, "penalties_order", 3)

    assert_equal "1st", row("Penalties").left
    assert_equal "3rd", row("Penalties").right
    assert_equal :left, row("Penalties").leader
  end

  test "the figures come grouped, and an empty group is not drawn" do
    reading(@salah, "season_points", 120)
    reading(@salah, "now_cost", 130)

    assert_equal [ "This season", "What the market says" ], stats.map(&:title)
  end

  test "nothing recorded means nothing to compare" do
    assert_empty stats
  end
end
