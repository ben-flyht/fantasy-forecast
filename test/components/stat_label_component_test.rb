require "test_helper"

class StatLabelComponentTest < ViewComponent::TestCase
  test "a defined term opens its definition from the label" do
    render_inline(StatLabelComponent.new(term: StatGlossary.fetch(:expected_goals_per_90)))

    button = page.find("button", text: "xG per 90")
    assert_selector "[popover][id='#{button['popovertarget']}']", text: "Expected goals", visible: :all
  end

  test "a plain term is only its label" do
    render_inline(StatLabelComponent.new(term: StatGlossary.fetch(:minutes)))

    assert_text "Minutes"
    assert_no_selector "button"
  end
end
