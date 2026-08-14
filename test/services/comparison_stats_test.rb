require "test_helper"

class ComparisonStatsTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
    @gameweek = gameweeks(:next_gw)
    Statistic.delete_all
  end

  def reading(player, type, value)
    Statistic.create!(player: player, gameweek: @gameweek, type: type, value: value)
  end

  def stats
    ComparisonStats.call(left: @salah, right: @palmer)
  end

  def row(label)
    stats.flat_map(&:rows).find { |r| r.label == label }
  end

  test "nothing recorded means nothing to compare" do
    assert_empty stats
  end

  test "the record is grouped under one heading" do
    reading(@salah, "expected_goals_per_90", 0.5)

    assert_equal "Underlying numbers", stats.first.title
  end

  # Rates, totals, form and indices sit together, each row labelled with what it is so
  # a per-90 rate is never mistaken for a total.
  test "per-90 rates, totals, form and indices sit side by side, each labelled" do
    reading(@salah, "form", 5.2)
    reading(@salah, "season_points", 120)
    reading(@salah, "season_goals", 9)
    reading(@salah, "expected_goals_per_90", 0.55)
    reading(@salah, "ict_index", 145.3)

    labels = stats.flat_map(&:rows).map(&:label)
    assert_includes labels, "Form"
    assert_includes labels, "Points"
    assert_includes labels, "Goals"
    assert_includes labels, "Expected goals, per 90"
    assert_includes labels, "ICT index"
  end

  # A total reads whole, a rate to two places, form to one.
  test "each figure reads in its own shape" do
    reading(@salah, "season_points", 120)
    reading(@salah, "expected_goals_per_90", 0.55)
    reading(@salah, "form", 5.2)

    assert_equal "120", row("Points").left
    assert_equal "0.55", row("Expected goals, per 90").left
    assert_equal "5.2", row("Form").left
  end

  test "the stronger number leads, and for goals conceded fewer is better" do
    reading(@salah, "season_goals", 9)
    reading(@palmer, "season_goals", 4)
    reading(@salah, "expected_goals_conceded_per_90", 1.4)
    reading(@palmer, "expected_goals_conceded_per_90", 0.9)

    assert_equal :left, row("Goals").leader
    assert_equal :right, row("Expected goals conceded, per 90").leader
  end

  # Before a ball is kicked this season the record is last season's.
  test "until the season starts, the numbers are last season's" do
    Gameweek.update_all(is_finished: false)
    reading(@salah, "last_season_points", 200)
    reading(@salah, "season_points", 0)

    assert_equal "200", row("Points").left
  end

  test "a figure with no last-season record waits until the season starts" do
    Gameweek.update_all(is_finished: false)
    reading(@salah, "ict_index", 100)

    assert_nil row("ICT index")
  end

  # You own both, so between them they do the sum.
  test "a side's figure is its players' summed" do
    reading(@salah, "season_goals", 9)
    reading(@palmer, "season_goals", 4)
    reading(@raya, "season_goals", 0)

    row = ComparisonStats.call(left: [ @salah, @palmer ], right: @raya)
                         .flat_map(&:rows).find { |r| r.label == "Goals" }

    assert_equal "13", row.left
    assert_equal "0", row.right
    assert_equal :left, row.leader
  end

  test "a side missing one man's figure is blank rather than half of one" do
    reading(@salah, "season_goals", 9)
    reading(@raya, "season_goals", 2)

    row = ComparisonStats.call(left: [ @salah, @palmer ], right: @raya)
                         .flat_map(&:rows).find { |r| r.label == "Goals" }

    assert_equal "—", row.left
    assert_equal "2", row.right
  end

  test "a figure neither side has is not a row" do
    reading(@salah, "form", 5.0)

    assert_equal [ "Form" ], stats.flat_map(&:rows).map(&:label)
  end
end
