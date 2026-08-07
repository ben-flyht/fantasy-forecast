require "test_helper"

class ShareCard::TeamSheetTest < ActiveSupport::TestCase
  # The picks themselves are only ever used as keys here, so they can be anything.
  def sheet_for(starters, bench: four, names: nil)
    ShareCard::TeamSheet.new(starters: starters, bench: bench,
                             names: names || (starters + bench).index_with { "SALAH" })
  end

  def eleven = (1..11).map(&:to_s)

  def on_a_phone(size) = size * ShareCard::TeamSheet::MOBILE_SCALE

  def four = (12..15).map(&:to_s)

  test "every player gets a row" do
    sheet = sheet_for(eleven)

    assert_equal 15, sheet.starters.size + sheet.bench.size
  end

  test "an odd eleven splits with the spare row in the first column" do
    columns = sheet_for(eleven).starters.group_by(&:x)

    assert_equal 2, columns.size
    assert_equal [ 6, 5 ], columns.values.map(&:size)
  end

  test "the columns do not overlap and stay on the card" do
    left, right = sheet_for(eleven).starters.map(&:x).uniq

    assert_operator left + ShareCard::TeamSheet::COLUMN_WIDTH, :<=, right
    assert_operator right + ShareCard::TeamSheet::COLUMN_WIDTH, :<=, ShareCard::WIDTH
  end

  test "rows in a column are evenly spaced and in the order given" do
    column = sheet_for(eleven).starters.group_by(&:x).values.first
    gaps = column.each_cons(2).map { |a, b| b.y - a.y }

    assert_equal [ ShareCard::TeamSheet::ROW_PITCH ] * (column.size - 1), gaps
    assert_equal eleven.first(6), column.map(&:pick)
  end

  test "the eleven finish above the label the bench sits under" do
    lowest = sheet_for(eleven).starters.map(&:y).max

    assert_operator lowest, :<, ShareCard::TeamSheet::BENCH_LABEL
  end

  # The bench is its own block under its own label, and four split evenly rather
  # than trailing the eleven down a column.
  test "the bench starts under its label and splits two and two" do
    columns = sheet_for(eleven).bench.group_by(&:x)

    assert_equal [ 2, 2 ], columns.values.map(&:size)
    assert_equal ShareCard::TeamSheet::BENCH_TOP, sheet_for(eleven).bench.map(&:y).min
  end

  test "the bench stays on the card" do
    lowest = sheet_for(eleven).bench.map(&:y).max

    assert_operator lowest, :<=, ShareCard::SQUARE
  end

  # Sizing each name to its own row puts the shortest name in the largest type,
  # which is what makes a card look like a ransom note.
  test "every name on the card is set at one size, the longest one's" do
    names = (eleven + four).index_with { "SON" }.merge("1" => "GIBBS-WHITE")
    sheet = sheet_for(eleven, names: names)

    assert_equal ShareCard.fitted_size("GIBBS-WHITE", width: sheet.room,
                                       max: ShareCard::TeamSheet::NAME_MAX),
                 sheet.name_size
  end

  # A list gives a name far more room than five across a pitch ever did, which was
  # the whole reason for listing them.
  test "an ordinary name takes the largest size the card allows" do
    assert_equal ShareCard::TeamSheet::NAME_MAX, sheet_for(eleven).name_size
  end

  # The one thing this card exists to get right, and the one that kept regressing.
  # A phone draws it at under a third of its size, and anything that does not survive
  # that is not on the card, it is only taking up room on it.
  test "the longest name survives being shown on a phone" do
    sheet = sheet_for(eleven, names: (eleven + four).index_with { "CALVERT-LEWIN" })

    assert sheet.legible?, "names fall below the floor on a phone"
    assert_operator on_a_phone(sheet.name_size), :>=, ShareCard::TeamSheet::LEGIBLE_ON_A_PHONE
  end

  # The floor applies to everything on the card, not only the names: a club, a price
  # and a section label are as unreadable at six pixels as a name is. Every size comes
  # from the sheet rather than being typed into the template, so they cannot drift
  # under it one at a time.
  test "nothing on the card is set below the floor" do
    { "name" => sheet_for(eleven).name_size,
      "club and price" => ShareCard::TeamSheet::META_SIZE,
      "section label" => ShareCard::TeamSheet::LABEL_SIZE }.each do |what, size|
      assert_operator on_a_phone(size), :>=, ShareCard::TeamSheet::LEGIBLE_ON_A_PHONE,
                      "#{what} is #{on_a_phone(size).round(1)}px on a phone"
    end
  end

  # A photograph running under the names is the one thing this card must never do,
  # so the sheet owns the edge the drawing has to stop at rather than the template
  # carrying a number somebody will nudge.
  test "the photograph cannot reach the first name" do
    assert_operator ShareCard::TeamSheet::PHOTO_RIGHT, :<, ShareCard::TeamSheet::LEFT
    assert_equal ShareCard::TeamSheet::GUTTER,
               ShareCard::TeamSheet::LEFT - ShareCard::TeamSheet::PHOTO_RIGHT
  end

  # The photograph stands at the right of every row, so a name must never run under
  # him however long it is.
  test "a name is never wider than the room left beside the photograph" do
    longest = "WOLVERHAMPTON WANDERERS"
    sheet = sheet_for(eleven, names: (eleven + four).index_with { longest })
    drawn = ShareCard::ADVANCE * sheet.name_size * longest.length

    assert_operator drawn, :<=, sheet.room
  end
end
