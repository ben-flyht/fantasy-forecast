# frozen_string_literal: true

module Figures
  class FixtureTableComponentPreview < ViewComponent::Preview
    def upcoming
      render FixtureTableComponent.new(title: "Next 3 Fixtures", rows: PreviewFixtures.fixtures, points_label: "xP",
                                       empty_message: "No upcoming fixtures scheduled.")
    end

    def empty
      render FixtureTableComponent.new(title: "Next 0 Fixtures", rows: [], points_label: "xP",
                                       empty_message: "No upcoming fixtures scheduled.")
    end
  end
end
