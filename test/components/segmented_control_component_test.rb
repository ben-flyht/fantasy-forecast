require "test_helper"

class SegmentedControlComponentTest < ViewComponent::TestCase
  def options(current: "/b")
    [
      SegmentedControlComponent::Option.new(label: "One", url: "/a", current: current == "/a"),
      SegmentedControlComponent::Option.new(label: "Two", url: "/b", current: current == "/b")
    ]
  end

  # Every choice is an address, so a crawler can follow it and the control works
  # with JavaScript switched off.
  test "each choice is a link" do
    render_inline SegmentedControlComponent.new(label: "Position", options: options)

    assert_selector "[aria-label=Position] a", count: 2
    assert_selector "a[href='/a']", text: "One"
    assert_selector "a[href='/b']", text: "Two"
  end

  test "only the current choice says it is the page you are on" do
    render_inline SegmentedControlComponent.new(label: "Position", options: options(current: "/a"))

    assert_selector "a[aria-current=page]", count: 1
    assert_selector "a[href='/a'][aria-current=page]"
  end

  test "the current choice is the lit one" do
    render_inline SegmentedControlComponent.new(label: "Position", options: options(current: "/a"))

    assert_selector "a[href='/a'].bg-white"
    assert_no_selector "a[href='/b'].bg-white"
  end

  # Full width on a phone so each option is thumb-sized, its own width from sm up.
  test "it fills the row on a phone and shrinks to its content above that" do
    render_inline SegmentedControlComponent.new(label: "Position", options: options)

    assert_selector "div.flex.sm\\:inline-flex"
    assert_selector "a.flex-1.sm\\:flex-none", count: 2
  end

  # Four full position names across a phone would wrap to three lines, so the
  # breakpoint picks the short one and the accessible name stays the full one.
  test "a short name is offered alongside the full one" do
    render_inline SegmentedControlComponent.new(label: "Position", options: [
      SegmentedControlComponent::Option.new(label: "Goalkeepers", short_label: "GK", url: "/gk", current: true)
    ])

    assert_selector "a span.sm\\:hidden", text: "GK"
    assert_selector "a span.hidden.sm\\:inline", text: "Goalkeepers"
    assert_selector "a[aria-label=Goalkeepers]"
  end

  test "an option with no short name is drawn once, with no aria-label to override it" do
    render_inline SegmentedControlComponent.new(label: "Forecast horizon", options: [
      SegmentedControlComponent::Option.new(label: "Rest of Season", url: "/season", current: true)
    ])

    assert_selector "a", text: "Rest of Season"
    assert_no_selector "a span"
    assert_no_selector "a[aria-label]"
  end

  # A short name identical to the full one is not an abbreviation, so it does not
  # earn two spans and an aria-label.
  test "a short name the same as the full one is not treated as one" do
    render_inline SegmentedControlComponent.new(label: "Position", options: [
      SegmentedControlComponent::Option.new(label: "GK", short_label: "GK", url: "/gk", current: true)
    ])

    assert_no_selector "a span"
  end

  test "nothing to choose between means nothing is drawn" do
    render_inline SegmentedControlComponent.new(label: "Position", options: [])

    assert_no_selector "[aria-label=Position]"
  end
end
