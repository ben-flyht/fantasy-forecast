require "test_helper"

class SparklineComponentTest < ViewComponent::TestCase
  test "a falling line is drawn in the same zinc as a rising one" do
    render_inline SparklineComponent.new(values: [ 4, 3, 2, 1 ])
    falling = page.find("svg")[:class]

    render_inline SparklineComponent.new(values: [ 1, 2, 3, 4 ])

    assert_equal falling, page.find("svg")[:class]
    assert_selector "svg.text-zinc-900 polyline[stroke=currentColor]"
  end
end
