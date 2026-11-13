require "test_helper"

class FormStripComponentTest < ViewComponent::TestCase
  Week = Struct.new(:fpl_id)

  def row(gameweek, points)
    { gameweek: Week.new(gameweek), opponent: Team.new(name: "Chelsea", short_name: "CHE"), home: true, points: points }
  end

  def strip(rows)
    render_inline FormStripComponent.new(title: "Recent Form", rows: rows, empty_message: "No matches played yet.")
  end

  test "each week's points stand directly on its bar" do
    strip([ row(7, 6) ])

    assert_selector "li p + span.bg-ink"
    assert_selector "li p", text: "6"
  end

  test "the weeks read oldest to newest, however they are handed over" do
    strip([ row(9, 2), row(8, 13), row(7, 6) ])

    assert_equal %w[GW7 GW8 GW9], page.all("li p:last-child").map(&:text)
  end

  test "a blank is drawn quietly and a return in ink" do
    strip([ row(7, 2), row(8, 13) ])

    assert_selector "li:first-child span.bg-line-strong"
    assert_selector "li:last-child span.bg-ink"
  end

  test "the best week fills the strip and the rest are measured against it" do
    strip([ row(7, 10), row(8, 20) ])

    assert_selector "li:first-child span[style='height: calc((100% - 1.5rem) * 0.5)']"
    assert_selector "li:last-child span[style='height: calc((100% - 1.5rem) * 1.0)']"
  end

  test "no matches says so instead of drawing an empty strip" do
    strip([])

    assert_text "No matches played yet."
    assert_no_selector "ol"
  end
end
