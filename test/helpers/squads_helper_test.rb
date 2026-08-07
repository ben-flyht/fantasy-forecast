require "test_helper"

class SquadsHelperTest < ActionView::TestCase
  # Football's own two letters, not FPL's three, because the column is sized for
  # something short. Midfielder is MF: MD is not an abbreviation anybody uses.
  test "every position has the abbreviation football actually uses" do
    assert_equal "GK", position_letter("goalkeeper")
    assert_equal "DF", position_letter("defender")
    assert_equal "MF", position_letter("midfielder")
    assert_equal "FW", position_letter("forward")
  end

  test "a position we do not know is marked rather than left blank" do
    assert_equal "?", position_letter("sweeper")
    assert_equal "?", position_letter(nil)
  end
end
