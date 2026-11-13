# frozen_string_literal: true

module Figures
  class LeaderboardComponentPreview < ViewComponent::Preview
    ROWS = [
      { place: "1st", name: "Haaland's Hairband", points: 61, accuracy: 84, pro: true },
      { place: "2nd", name: "Sam B", points: 57, accuracy: 79 },
      { place: "3rd", name: "Kerr Blimey", points: 52, accuracy: 71, pro: true },
      { place: "14th", name: "Saka Potatoes", points: 31, accuracy: 48, mine: true, gap: true }
    ].freeze

    def weekly
      render_with_template locals: { rows: ROWS }
    end
  end
end
