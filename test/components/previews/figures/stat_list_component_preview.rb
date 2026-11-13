# frozen_string_literal: true

module Figures
  class StatListComponentPreview < ViewComponent::Preview
    def default
      render StatListComponent.new(rows: [
        [ "Expected goals per 90", "0.74" ], [ "Expected assists per 90", "0.19" ], [ "Price", "£14.5m" ]
      ])
    end
  end
end
