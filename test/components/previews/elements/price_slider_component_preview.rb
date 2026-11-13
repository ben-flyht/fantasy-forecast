# frozen_string_literal: true

module Elements
  class PriceSliderComponentPreview < ViewComponent::Preview
    def full_range
      render_with_template locals: { filter: { min: 4.0, max: 15.0, floor: 4.0, ceil: 15.0, step: 0.5 } }
    end

    def narrowed
      render_with_template template: "elements/price_slider_component_preview/full_range",
                           locals: { filter: { min: 6.5, max: 10.0, floor: 4.0, ceil: 15.0, step: 0.5 } }
    end
  end
end
