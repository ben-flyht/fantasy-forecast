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

  # Rates, totals and form sit together, each row labelled with what it is so a per-90
  # rate is never mistaken for a total.
  test "per-90 rates, totals and form sit side by side, each labelled" do
    reading(@salah, "form", 5.2)
    reading(@salah, "season_points", 120)
    reading(@salah, "season_goals", 9)
    reading(@salah, "expected_goals_per_90", 0.55)
    reading(@salah, "expected_assists_per_90", 0.31)

    labels = stats.flat_map(&:rows).map(&:label)
    assert_includes labels, "Form"
    assert_includes labels, "Total points"
    assert_includes labels, "Goals"
    assert_includes labels, "xG per 90"
    assert_includes labels, "xA per 90"
  end

  # A total reads whole, a rate to two places, form to one.
  test "each figure reads in its own shape" do
    reading(@salah, "season_points", 120)
    reading(@salah, "expected_goals_per_90", 0.55)
    reading(@salah, "form", 5.2)

    assert_equal "120", row("Total points").left
    assert_equal "0.55", row("xG per 90").left
    assert_equal "5.2", row("Form").left
  end

  test "the stronger number leads, and for goals conceded fewer is better" do
    reading(@salah, "season_goals", 9)
    reading(@palmer, "season_goals", 4)
    reading(@salah, "expected_goals_conceded_per_90", 1.4)
    reading(@palmer, "expected_goals_conceded_per_90", 0.9)

    assert_equal :left, row("Goals").leader
    assert_equal :right, row("xGC per 90").leader
  end

  # Before a ball is kicked this season the record is last season's.
  test "until the season starts, the numbers are last season's" do
    Gameweek.update_all(is_finished: false)
    reading(@salah, "last_season_points", 200)
    reading(@salah, "season_points", 0)

    assert_equal "200", row("Total points").left
  end

  test "a figure with no last-season record waits until the season starts" do
    Gameweek.update_all(is_finished: false)
    reading(@salah, "form", 5.0)

    assert_nil row("Form")
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

  # Nought on both sides says nothing, so it is not drawn.
  test "a row that is nought on both sides is not drawn" do
    reading(@salah, "season_goals", 0)
    reading(@palmer, "season_goals", 0)

    assert_nil row("Goals")
  end

  test "two equal figures light neither side" do
    reading(@salah, "form", 4.0)
    reading(@palmer, "form", 4.0)

    assert_nil row("Form").leader
  end

  test "a row FPL pays nobody on either side for is not drawn" do
    forward = players(:brazilian)
    reading(forward, "saves_per_90", 0.2)
    reading(forward, "clean_sheets_per_90", 0.4)
    reading(forward, "defensive_contribution_per_90", 3.9)

    rows = ComparisonStats.call(left: forward, right: forward).flat_map(&:rows).map(&:label)

    assert_not_includes rows, "Saves per 90"
    assert_not_includes rows, "Clean sheets per 90"
    assert_includes rows, "Defensive actions per 90"
  end

  test "a row is drawn when anybody on either side is paid for it" do
    forward = players(:brazilian)
    reading(forward, "clean_sheets_per_90", 0.4)
    reading(@salah, "clean_sheets_per_90", 0.6)

    rows = ComparisonStats.call(left: forward, right: @salah).flat_map(&:rows).map(&:label)

    assert_includes rows, "Clean sheets per 90"
  end

  test "the penalty taker leads, and a fourth choice is no taker at all" do
    reading(@salah, "penalties_order", 1)
    reading(@palmer, "penalties_order", 4)

    assert_equal "1st", row("Penalties").left
    assert_equal "—", row("Penalties").right
    assert_equal :left, row("Penalties").leader
  end

  test "nobody on penalties is no row" do
    reading(@salah, "form", 5.0)

    assert_nil row("Penalties")
  end

  test "rows carry the definition behind their label" do
    reading(@salah, "expected_goals_per_90", 0.5)

    assert_match "Expected goals", row("xG per 90").term.definition
  end
end
