require "test_helper"

class PageHeadingComponentTest < ViewComponent::TestCase
  def horizons(current: :gameweek)
    [
      PageHeadingComponent::Horizon.new(label: "Gameweek 1", url: "/gameweeks/1/forwards", current: current == :gameweek),
      PageHeadingComponent::Horizon.new(label: "Rest of Season", url: "/season/forwards", current: current == :season)
    ]
  end

  test "a title is all it needs" do
    render_inline PageHeadingComponent.new(title: "Best FPL Forwards")

    assert_selector "h1", text: "Best FPL Forwards"
    assert_no_selector "p"
  end

  # A page with nowhere to go back to and nothing to share draws no utility row at
  # all, rather than drawing an empty one and leaving a gap above the title.
  test "no back link and nothing to share means no row above the title" do
    render_inline PageHeadingComponent.new(title: "Anything", subtitle: "A line")

    assert_no_selector "button[data-controller=share]"
    assert_no_selector ".justify-end"
  end

  test "share alone sits at the right of the row" do
    render_inline PageHeadingComponent.new(title: "Anything", share: "Share these rankings")

    assert_selector ".justify-end button[data-controller=share]"
    assert_no_selector ".justify-between"
  end

  # The face says "Share" so it fits beside a back link on a phone. What is being
  # shared is still said, to a screen reader and to the share sheet.
  test "the button reads Share, and says in full what it shares" do
    render_inline PageHeadingComponent.new(title: "Gabriel", share: "Share Gabriel's forecast")

    assert_selector "button", text: "Share"
    assert_no_selector "button", text: "Share Gabriel's forecast"
    assert_selector %(button[aria-label="Share Gabriel's forecast"])
    assert_selector %(button[data-share-title-value="Share Gabriel's forecast"])
  end

  # This heading is drawn inside a turbo frame on the rankings, and a link in a
  # frame swaps the frame rather than the page. Going back has to leave.
  test "the back link breaks out of any frame it is drawn in" do
    render_inline PageHeadingComponent.new(
      title: "Best FPL Forwards",
      back: PageHeadingComponent::Back.new(label: "Back to Home", url: "/")
    )

    assert_selector "a[href='/'][data-turbo-frame='_top']", text: "Back to Home"
  end

  test "a back link and a share button share the row" do
    render_inline PageHeadingComponent.new(
      title: "Gabriel", share: "Share him",
      back: PageHeadingComponent::Back.new(label: "Back to Rankings", url: "/rankings")
    )

    assert_selector ".justify-between a[href='/rankings']", text: "Back to Rankings"
    assert_selector ".justify-between button[data-controller=share]"
  end

  # Links rather than a form, so both horizons are addresses a crawler can follow.
  test "the horizons are links, and the current one says so" do
    render_inline PageHeadingComponent.new(title: "Best FPL Forwards", horizons: horizons(current: :season))

    assert_selector "[aria-label='Forecast horizon'] a", count: 2
    assert_selector "a[href='/season/forwards'][aria-current=page]", text: "Rest of Season"
    assert_selector "a[href='/gameweeks/1/forwards']:not([aria-current])", text: "Gameweek 1"
  end

  test "an empty list of horizons draws no toggle" do
    render_inline PageHeadingComponent.new(title: "Who to Captain", horizons: [])

    assert_no_selector "[aria-label='Forecast horizon']"
  end

  test "the timestamp says when, in words and in a machine-readable time" do
    moment = 12.minutes.ago
    render_inline PageHeadingComponent.new(title: "Best FPL Forwards", updated_at: moment)

    assert_selector %(time[datetime="#{moment.iso8601}"]), text: "12 minutes ago"
  end

  # A lone timestamp hanging off the right of a heading reads as something left
  # behind, so with no toggle it takes the toggle's place instead.
  test "with no toggle the timestamp takes the toggle's slot" do
    render_inline PageHeadingComponent.new(title: "Who to Captain", updated_at: 1.hour.ago)

    assert_selector "p.sm\\:col-start-1.sm\\:justify-self-start"
  end

  test "with a toggle the timestamp sits opposite it" do
    render_inline PageHeadingComponent.new(title: "Best FPL Forwards", updated_at: 1.hour.ago, horizons: horizons)

    assert_selector "p.sm\\:col-start-2.sm\\:justify-self-end"
  end
end
