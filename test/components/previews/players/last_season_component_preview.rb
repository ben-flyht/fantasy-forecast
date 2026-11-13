# frozen_string_literal: true

module Players
  class LastSeasonComponentPreview < ViewComponent::Preview
    def midfielder
      render LastSeasonComponent.new(stats: PreviewFixtures::LAST_SEASON, position: "midfielder")
    end

    def goalkeeper
      stats = PreviewFixtures::LAST_SEASON.merge("last_season_saves_per_90" => 3.1, "last_season_goals_per_90" => 0,
                                                 "last_season_assists" => 0)
      render LastSeasonComponent.new(stats: stats, position: "goalkeeper")
    end
  end
end
