# frozen_string_literal: true

module Figures
  class PlayerOptionsComponentPreview < ViewComponent::Preview
    def gameweek
      render options("gameweek")
    end

    def season
      render options("season")
    end

    private

    def options(horizon)
      PlayerOptionsComponent.new(entries: PreviewFixtures.options, horizon: horizon, cost: 100, score: 6.1,
                                 title: "Competing for a start",
                                 subtitle: "Every midfielder at Arsenal, best forecast first.")
    end
  end
end
