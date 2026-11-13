# frozen_string_literal: true

module Figures
  class StatComparisonComponentPreview < ViewComponent::Preview
    def default
      render StatComparisonComponent.new(rows: [
        row(:form, "3.5", "2.8", :left, [ 1.0, 0.8 ]),
        row(:points, "52", "47", :left, [ 1.0, 0.9 ]),
        row(:minutes, "880", "878", :left, [ 1.0, 0.99 ]),
        row(:expected_goals_per_90, "0.31", "0.38", :right, [ 0.82, 1.0 ]),
        row(:assists, "3", "3", nil, [ 1.0, 1.0 ]),
        row(:penalties, "1st", "—", :left, nil),
        row(:yellow_cards, "4", "1", :right, [ 0.25, 1.0 ])
      ])
    end

    def one_sided
      render StatComparisonComponent.new(rows: [
        row(:goals, "9", "0", :left, [ 1.0, 0.0 ]),
        row(:points, "—", "47", nil, nil)
      ])
    end

    private

    def row(term, left, right, leader, shares)
      ComparisonStats::Row.new(term: StatGlossary.fetch(term), left: left, right: right, leader: leader, shares: shares)
    end
  end
end
