require "test_helper"

class MostRequestedComparisonsTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
    ComparisonRequest.delete_all
  end

  def pair(a, b)
    Comparison.new(a, b).slug
  end

  test "the most asked pair leads" do
    hot = pair(@salah, @palmer)
    cold = pair(@salah, @raya)
    3.times { ComparisonRequest.record(hot) }
    ComparisonRequest.record(cold)

    assert_equal [ hot, cold ], MostRequestedComparisons.call.map(&:slug)
  end

  # A group is counted the same as a pair, but the hub is a page to scan, so only the
  # straight choices are offered.
  test "groups are counted but never surfaced" do
    group = Comparison.new([ @salah, @raya ], @palmer).slug
    straight = pair(@salah, @palmer)
    5.times { ComparisonRequest.record(group) }
    ComparisonRequest.record(straight)

    surfaced = MostRequestedComparisons.call

    assert_equal [ straight ], surfaced.map(&:slug)
    assert surfaced.none?(&:group?)
  end

  test "a slug that no longer names anybody is skipped" do
    ComparisonRequest.record("nobody-98-vs-nobody-99")
    good = pair(@salah, @palmer)
    ComparisonRequest.record(good)

    assert_equal [ good ], MostRequestedComparisons.call.map(&:slug)
  end
end
