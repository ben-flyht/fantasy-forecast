require "test_helper"

class ComparisonStatsTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @gameweek = gameweeks(:next_gw)
    # Both halves of the table are cleared, so a test that says a figure is missing
    # is describing an empty page rather than a page full of fixtures.
    Statistic.delete_all
    Forecast.delete_all
  end

  def expectation(player, horizon, score)
    Forecast.create!(player: player, gameweek: @gameweek, horizon: horizon, score: score, rank: 1)
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

  # The answer leads and the working follows. A manager who disagrees with the pick
  # reads down from it; he should not have to read up to find it.
  test "what we expect comes first, at all three distances" do
    expectation(@salah, Horizon::GAMEWEEK, 6.4)
    expectation(@salah, Horizon::UPCOMING, 30.9)
    expectation(@salah, Horizon::SEASON, 244.6)

    assert_equal "What we expect", stats.first.title
    assert_equal [ "This gameweek", "Next 5 gameweeks", "Rest of season" ],
                 stats.first.rows.map(&:label)
    assert_equal "6.4", row("This gameweek").left
    assert_equal "245", row("Rest of season").left,
                 "a tenth of a point over a season is a precision we do not have"
  end

  test "the man we expect more of leads the row" do
    expectation(@salah, Horizon::SEASON, 244.6)
    expectation(@palmer, Horizon::SEASON, 190.2)

    assert_equal :left, row("Rest of season").leader
  end

  # FPL leaves last season's totals in the current-season fields all summer, so
  # before a ball is kicked this group is last season's record under this season's
  # name. That is the reading that had the page arguing with its own answer.
  test "there is no this season until a gameweek has been played" do
    reading(@salah, "season_points", 120)
    Gameweek.update_all(is_finished: false)

    assert_not_includes stats.map(&:title), "This season"

    gameweeks(:finished).update!(is_finished: true)

    assert_includes stats.map(&:title), "This season"
  end

  # A side is a player or the players you would buy together, and a figure for two
  # men is not always the two figures added up.

  def paired_stats
    ComparisonStats.call(left: [ @salah, @palmer ], right: players(:goalkeeper))
  end

  def paired_row(label)
    paired_stats.flat_map(&:rows).find { |r| r.label == label }
  end

  # You own both, so you collect both.
  test "a total is what the side scored between them" do
    reading(@salah, "season_points", 120)
    reading(@palmer, "season_points", 90)
    reading(players(:goalkeeper), "season_points", 150)

    assert_equal "210", paired_row("Total points").left
    assert_equal :left, paired_row("Total points").leader
  end

  test "a side missing one man's figure is blank rather than half of one" do
    reading(@salah, "season_points", 120)
    reading(players(:goalkeeper), "season_points", 150)

    assert_equal "—", paired_row("Total points").left
  end

  # Two rates per ninety minutes are not one rate when added. This is what the pair
  # did between them, so the man who played more counts for more.
  test "a rate per 90 is weighed by the football each of them played" do
    reading(@salah, "expected_goals_per_90", 0.60)
    reading(@salah, "season_minutes", 900)
    reading(@palmer, "expected_goals_per_90", 0.20)
    reading(@palmer, "season_minutes", 300)
    reading(players(:goalkeeper), "expected_goals_per_90", 0.10)

    assert_equal "0.50", paired_row("Expected goals").left
  end

  # A share of the game's managers belongs to one man, and so does a place in a
  # penalty queue. Neither adds up, so each is written out and the row favours nobody.
  test "a figure that belongs to one man is written out for each of them" do
    reading(@salah, "penalties_order", 1)
    reading(@palmer, "penalties_order", 3)
    reading(players(:goalkeeper), "penalties_order", 2)

    assert_equal "1st and 3rd", paired_row("Penalties").left
    assert_equal "2nd", paired_row("Penalties").right
    assert_nil paired_row("Penalties").leader
  end

  test "what we expect of a side is what we expect of everybody on it" do
    expectation(@salah, "gameweek", 5.4)
    expectation(@palmer, "gameweek", 3.9)
    expectation(players(:goalkeeper), "gameweek", 4.0)

    assert_equal "9.3", paired_row("This gameweek").left
    assert_equal "4.0", paired_row("This gameweek").right
  end
end
