require "test_helper"

class MostRequestedComparisonsTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
    @gameweek = gameweeks(:next_gw)
    Comparison.delete_all
    Forecast.delete_all
  end

  def record(comparison, times = 1)
    times.times { Comparison.record(comparison, @gameweek) }
    comparison.slug
  end

  def most_requested(**options)
    MostRequestedComparisons.call(gameweek: @gameweek, **options)
  end

  test "the most asked pair leads" do
    hot = record(Matchup.new(@salah, @palmer), 3)
    cold = record(Matchup.new(@salah, @raya))

    assert_equal [ hot, cold ], most_requested.map(&:slug)
  end

  # A group is counted the same as a pair, but the hub is a page to scan, so only the
  # straight choices are offered — and a group slug is never even parsed.
  test "groups are counted but never surfaced" do
    record(Matchup.new([ @salah, @raya ], @palmer), 5)
    straight = record(Matchup.new(@salah, @palmer))

    surfaced = most_requested

    assert_equal [ straight ], surfaced.map(&:slug)
    assert surfaced.none?(&:group?)
  end

  test "the limit is respected" do
    record(Matchup.new(@salah, @palmer), 3)
    record(Matchup.new(@salah, @raya), 2)

    assert_equal 1, most_requested(limit: 1).size
  end

  # A pair asked for when both were in the game, one of whom has since been transferred
  # out, no longer resolves — so it is skipped rather than raising.
  test "a slug that no longer names anybody is skipped" do
    Comparison.create!(gameweek: @gameweek, slug: "nobody-98-vs-nobody-99", pair: true, hits: 9)
    good = record(Matchup.new(@salah, @palmer))

    assert_equal [ good ], most_requested.map(&:slug)
  end

  test "the forecast's closest pairs are not passed off as asked" do
    Forecast.create!(player: @salah, gameweek: @gameweek, horizon: "gameweek", score: 6.0, rank: 1)
    Forecast.create!(player: @palmer, gameweek: @gameweek, horizon: "gameweek", score: 5.8, rank: 2)

    assert_empty most_requested
  end

  test "last week's asks carry over" do
    Comparison.record(Matchup.new(@salah, @palmer), gameweeks(:finished))

    assert_equal [ Matchup.new(@salah, @palmer).slug ], most_requested.map(&:slug)
  end

  test "a pair asked this week outweighs one asked as often last week" do
    3.times { Comparison.record(Matchup.new(@salah, @raya), gameweeks(:finished)) }
    fresh = record(Matchup.new(@salah, @palmer), 2)

    assert_equal fresh, most_requested.first.slug
  end

  test "a pair asked in both weeks has its hits added together" do
    2.times { Comparison.record(Matchup.new(@salah, @palmer), gameweeks(:finished)) }
    both = record(Matchup.new(@salah, @palmer), 1)
    record(Matchup.new(@salah, @raya), 1)

    assert_equal both, most_requested.first.slug
  end

  test "the week's asks are its own" do
    record(Matchup.new(@salah, @palmer))

    other_week = MostRequestedComparisons.call(gameweek: gameweeks(:finished))

    assert_empty other_week
  end
end
