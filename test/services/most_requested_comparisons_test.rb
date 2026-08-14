require "test_helper"

class MostRequestedComparisonsTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
    ComparisonRequest.delete_all
  end

  def record(comparison, times = 1)
    times.times { ComparisonRequest.record(comparison) }
    comparison.slug
  end

  test "the most asked pair leads" do
    hot = record(Comparison.new(@salah, @palmer), 3)
    cold = record(Comparison.new(@salah, @raya))

    assert_equal [ hot, cold ], MostRequestedComparisons.call.map(&:slug)
  end

  # A group is counted the same as a pair, but the hub is a page to scan, so only the
  # straight choices are offered — and a group slug is never even parsed.
  test "groups are counted but never surfaced" do
    record(Comparison.new([ @salah, @raya ], @palmer), 5)
    straight = record(Comparison.new(@salah, @palmer))

    surfaced = MostRequestedComparisons.call

    assert_equal [ straight ], surfaced.map(&:slug)
    assert surfaced.none?(&:group?)
  end

  test "the limit is respected" do
    record(Comparison.new(@salah, @palmer), 3)
    record(Comparison.new(@salah, @raya), 2)

    assert_equal 1, MostRequestedComparisons.call(limit: 1).size
  end

  # A pair asked for when both were in the game, one of whom has since been transferred
  # out, no longer resolves — so it is skipped rather than raising.
  test "a slug that no longer names anybody is skipped" do
    ComparisonRequest.create!(slug: "nobody-98-vs-nobody-99", pair: true, hits: 9)
    good = record(Comparison.new(@salah, @palmer))

    assert_equal [ good ], MostRequestedComparisons.call.map(&:slug)
  end
end
