require "test_helper"

class ComparisonRequestTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
    ComparisonRequest.delete_all
  end

  test "the first ask creates a row, the next bumps it rather than duplicating" do
    ComparisonRequest.record(Comparison.new(@salah, @palmer))
    ComparisonRequest.record(Comparison.new(@salah, @palmer))

    assert_equal 1, ComparisonRequest.count
    assert_equal 2, ComparisonRequest.find_by(slug: Comparison.new(@salah, @palmer).slug).hits
  end

  # The hub reads pairs by their flag, so a group must be marked as not one.
  test "a pair is marked a pair, a group is not" do
    ComparisonRequest.record(Comparison.new(@salah, @palmer))
    ComparisonRequest.record(Comparison.new([ @salah, @raya ], @palmer))

    assert ComparisonRequest.find_by(slug: Comparison.new(@salah, @palmer).slug).pair
    assert_not ComparisonRequest.find_by(slug: Comparison.new([ @salah, @raya ], @palmer).slug).pair
  end
end
