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

  test "once the season is under way, the numbers are this season's" do
    reading(@salah, "expected_goals_per_90", 0.55)
    reading(@palmer, "expected_goals_per_90", 0.30)

    assert_equal "This season, per 90", stats.first.title
    assert_equal "0.55", row("Expected goals").left
    assert_equal :left, row("Expected goals").leader
  end

  # Before a ball is kicked this season there is no this-season record, so the numbers
  # are last season's.
  test "until the season starts, the numbers are last season's" do
    Gameweek.update_all(is_finished: false)
    reading(@salah, "last_season_expected_goals_per_90", 0.60)
    reading(@salah, "expected_goals_per_90", 0.10)

    assert_equal "Last season, per 90", stats.first.title
    assert_equal "0.60", row("Expected goals").left
  end

  # A figure FPL did not keep last season simply waits until this season provides it.
  test "a figure with no last-season record is not drawn until the season starts" do
    Gameweek.update_all(is_finished: false)
    reading(@salah, "expected_goals_conceded_per_90", 1.20)

    assert_nil row("Expected goals conceded")
  end

  test "goals and assists, and starts, are among the numbers" do
    reading(@salah, "expected_goal_involvements_per_90", 0.80)
    reading(@salah, "starts_per_90", 1.00)

    labels = stats.flat_map(&:rows).map(&:label)
    assert_includes labels, "Expected goals and assists"
    assert_includes labels, "Starts"
  end

  # You own both, so between them they do the sum.
  test "a side's rate is its players' summed" do
    reading(@salah, "expected_goals_per_90", 0.50)
    reading(@palmer, "expected_goals_per_90", 0.30)
    reading(@raya, "expected_goals_per_90", 0.05)

    row = ComparisonStats.call(left: [ @salah, @palmer ], right: @raya)
                         .flat_map(&:rows).find { |r| r.label == "Expected goals" }

    assert_equal "0.80", row.left
    assert_equal "0.05", row.right
    assert_equal :left, row.leader
  end

  # Conceding fewer expected goals is the good end of that figure.
  test "for goals conceded, fewer is better" do
    reading(@salah, "expected_goals_conceded_per_90", 1.40)
    reading(@palmer, "expected_goals_conceded_per_90", 0.90)

    assert_equal :right, row("Expected goals conceded").leader
  end

  test "two equal figures light neither side" do
    reading(@salah, "saves_per_90", 3.0)
    reading(@palmer, "saves_per_90", 3.0)

    assert_nil row("Saves").leader
  end

  test "a figure neither side has is not a row" do
    reading(@salah, "expected_goals_per_90", 0.5)

    assert_equal [ "Expected goals" ], stats.flat_map(&:rows).map(&:label)
  end

  # A total is only a total when we have all of it.
  test "a side missing one man's figure is blank rather than half of one" do
    reading(@salah, "expected_goals_per_90", 0.50)
    reading(@raya, "expected_goals_per_90", 0.10)

    row = ComparisonStats.call(left: [ @salah, @palmer ], right: @raya)
                         .flat_map(&:rows).find { |r| r.label == "Expected goals" }

    assert_equal "—", row.left
    assert_equal "0.10", row.right
  end
end
