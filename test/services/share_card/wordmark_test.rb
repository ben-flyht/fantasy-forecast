require "test_helper"

# The mark is arithmetic because nothing drawing a card can measure text. These are
# the things that arithmetic has to get right for it to still be the logo.
class ShareCard::WordmarkTest < ActiveSupport::TestCase
  def wordmark(size: 22, right: 1144, middle: 570)
    ShareCard::Wordmark.new(size: size, right: right, middle: middle)
  end

  test "it hangs from the right edge it was given" do
    mark = wordmark(right: 1144)

    assert_in_delta 1144, placed_at(mark.ink_transform) + mark.width, 0.1
  end

  # The words are outlines, not text, because librsvg ignores font-family and would
  # otherwise draw the mark in whatever face it happened to hold.
  test "the words are drawn as outlines scaled to their size" do
    assert_match(/\Am[\d\-.]/i, ShareCard::Wordmark::INK_PATH)
    assert_match(/scale\(44\.0\)/, wordmark(size: 44).ink_transform)
  end

  test "it is centred on the middle it was given" do
    mark = wordmark(middle: 570)

    assert_in_delta 570, corners(mark).map(&:last).sum / 4.0, 0.1
  end

  test "the field begins after the first word ends" do
    mark = wordmark
    ink_ends = placed_at(mark.ink_transform) + (ShareCard::Wordmark::INK_WIDTH * mark.size)

    assert_operator placed_at(mark.field_transform), :>, ink_ends
  end

  test "both words sit on one baseline, inside the field" do
    mark = wordmark
    top, bottom = corners(mark).map(&:last).minmax

    assert_operator mark.baseline, :>, top
    assert_operator mark.baseline, :<, bottom
  end

  # The cut leans the way every clip-path on the site leans: the top edge starts
  # further right than the bottom edge does.
  test "the field is cut at the site's angle" do
    mark = wordmark
    (top_left, _), _, _, (bottom_left, _) = corners(mark)

    assert_operator top_left, :>, bottom_left
    assert_in_delta ShareCard::Wordmark::TAN, (top_left - bottom_left) / mark.height, 0.01
  end

  test "it scales with its size and nothing else" do
    small = wordmark(size: 22)
    large = wordmark(size: 44)

    assert_in_delta 2.0, large.width / small.width, 0.01
    assert_in_delta 2.0, large.height / small.height, 0.01
  end

  private

  def corners(mark)
    mark.points.split.map { |pair| pair.split(",").map(&:to_f) }
  end

  def placed_at(transform)
    transform[/translate\(([\d\-.]+)/, 1].to_f
  end
end
