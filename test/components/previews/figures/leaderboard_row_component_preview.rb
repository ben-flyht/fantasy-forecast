# frozen_string_literal: true

module Figures
  class LeaderboardRowComponentPreview < ViewComponent::Preview
    def states
      render_with_template locals: { rows: [
        { place: "1st", name: "Haaland's Hairband", pro: true },
        { place: "2nd", name: "Sam B" },
        { place: "9th", name: "Saka Potatoes", mine: true },
        { place: nil, name: "Yet To Play" },
        { place: "41st", name: "After The Gap", gap: true }
      ] }
    end
  end
end
