# frozen_string_literal: true

module Players
  class AlternativesComponentPreview < ViewComponent::Preview
    def upgrades_available
      render alternatives(upgrade: true)
    end

    def nobody_better
      render alternatives(upgrade: false)
    end

    private

    def alternatives(upgrade:)
      AlternativesComponent.new(comparison: PreviewFixtures.comparison(upgrade: upgrade),
                                player: PreviewFixtures.player(:saka), horizon: "gameweek")
    end
  end
end
