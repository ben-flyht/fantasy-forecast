# frozen_string_literal: true

module Players
  class ForecastWorkingComponentPreview < ViewComponent::Preview
    def single_fixture
      render_with_template template: "players/forecast_working_component_preview/panel",
                           locals: { working: PreviewFixtures::WORKING, horizon: "gameweek", position: "forward", chance: 100 }
    end

    def double_gameweek
      working = PreviewFixtures::WORKING.merge(games: 1.92, opponents: [
        { name: "Fulham", home: true, difficulty: 2 }, { name: "Arsenal", home: false, difficulty: 5 }
      ])
      render_with_template template: "players/forecast_working_component_preview/panel",
                           locals: { working: working, horizon: "gameweek", position: "forward", chance: 100 }
    end

    def season
      working = PreviewFixtures::WORKING.merge(games: 24.6, opponents: Array.new(26) { { name: "Fulham", home: true, difficulty: 3 } })
      render_with_template template: "players/forecast_working_component_preview/panel",
                           locals: { working: working, horizon: "season", position: "forward", chance: 100 }
    end

    def doubtful_goalkeeper
      render_with_template template: "players/forecast_working_component_preview/panel",
                           locals: { working: PreviewFixtures::WORKING.merge(crowd: nil), horizon: "gameweek",
                                     position: "goalkeeper", chance: 75 }
    end

    def blank_gameweek
      render_with_template template: "players/forecast_working_component_preview/panel",
                           locals: { working: PreviewFixtures::WORKING.merge(opponents: [], games: 0), horizon: "gameweek",
                                     position: "forward", chance: 100 }
    end
  end
end
