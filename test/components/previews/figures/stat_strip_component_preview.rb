# frozen_string_literal: true

module Figures
  class StatStripComponentPreview < ViewComponent::Preview
    def squad_summary
      render StatStripComponent.new(stats: [
        [ "Formation", "3-4-3" ], [ "Expected points", 71 ], [ "Spent", "£99.5m" ], [ "In the bank", "£0.5m" ]
      ])
    end

    def season_totals
      render StatStripComponent.new(stats: [
        [ "Total points", "78" ], [ "Points per £m", "5.4" ], [ "Best week", "17 (GW4)" ], [ "Blanks", "2 of 8" ]
      ])
    end
  end
end
