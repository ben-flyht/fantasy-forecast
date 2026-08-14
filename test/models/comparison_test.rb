require "test_helper"

class ComparisonTest < ActiveSupport::TestCase
  setup do
    @salah = players(:midfielder)
    @palmer = players(:midfielder_two)
    @raya = players(:goalkeeper)
    @gameweek = gameweeks(:next_gw)
    Comparison.delete_all
  end

  test "the first ask creates a row, the next bumps it rather than duplicating" do
    Comparison.record(Matchup.new(@salah, @palmer), @gameweek)
    Comparison.record(Matchup.new(@salah, @palmer), @gameweek)

    assert_equal 1, Comparison.count
    assert_equal 2, Comparison.find_by(slug: Matchup.new(@salah, @palmer).slug).hits
  end

  # The tally is per gameweek, so the same argument in a new week is a new row.
  test "a new gameweek is a new tally" do
    Comparison.record(Matchup.new(@salah, @palmer), @gameweek)
    Comparison.record(Matchup.new(@salah, @palmer), gameweeks(:finished))

    assert_equal 2, Comparison.count
  end

  # The hub reads pairs by their flag, so a group must be marked as not one.
  test "a pair is marked a pair, a group is not" do
    Comparison.record(Matchup.new(@salah, @palmer), @gameweek)
    Comparison.record(Matchup.new([ @salah, @raya ], @palmer), @gameweek)

    assert Comparison.find_by(slug: Matchup.new(@salah, @palmer).slug).pair
    assert_not Comparison.find_by(slug: Matchup.new([ @salah, @raya ], @palmer).slug).pair
  end
end
