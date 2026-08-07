require "test_helper"

# Nothing drawing a card can measure text: there is no layout engine, nothing reflows,
# and every element is placed by hand at an absolute coordinate. These are the two
# sums that stand in for measuring, and both have already been got wrong once.
class ShareCardTest < ActiveSupport::TestCase
  # Guessing this is how a label ends up printed across the number it belongs to,
  # which is exactly what happened before it existed: "61" at 148px is about 200
  # wide, and the label was being put down 92 along.
  test "it measures a string so the next thing can be put beside it" do
    assert_operator ShareCard.width_of("61", size: 148, advance: ShareCard::DIGIT), :>, 148
    assert_equal 0, ShareCard.width_of("", size: 148)
    assert_equal 0, ShareCard.width_of(nil, size: 148)
  end

  test "a wider size and a longer string both take more room" do
    small = ShareCard.width_of("FANTASY", size: 20)
    large = ShareCard.width_of("FANTASY", size: 40)
    longer = ShareCard.width_of("FANTASYFORECAST", size: 20)

    assert_in_delta 2.0, large.to_f / small, 0.01
    assert_operator longer, :>, small
  end

  # Digits are narrower than letters, and in Inter they are all exactly as wide as
  # each other, which is what makes a number safe to measure at all.
  test "digits are measured narrower than letters" do
    assert_operator ShareCard.width_of("11", size: 100, advance: ShareCard::DIGIT), :<,
                    ShareCard.width_of("11", size: 100)
  end

  test "a size is never larger than the maximum it is given" do
    assert_equal 40, ShareCard.fitted_size("A", width: 10_000, max: 40)
  end

  test "a long name is sized down until it fits the room it has" do
    room = 300
    size = ShareCard.fitted_size("CALVERT-LEWIN", width: room, max: 44)

    assert_operator size, :<, 44
    assert_operator ShareCard.width_of("CALVERT-LEWIN", size: size), :<=, room
  end

  test "nothing to draw takes the size it was offered" do
    assert_equal 44, ShareCard.fitted_size(nil, width: 10, max: 44)
    assert_equal 44, ShareCard.fitted_size("", width: 10, max: 44)
  end
end
