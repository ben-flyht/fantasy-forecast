# frozen_string_literal: true

module Players
  class PlayerRowComponentPreview < ViewComponent::Preview
    def dark_club
      render_with_template template: "players/player_row_component_preview/row",
                           locals: { entry: PreviewFixtures.entry(:salah, rank: 2) }
    end

    def light_club
      render_with_template template: "players/player_row_component_preview/row",
                           locals: { entry: PreviewFixtures.entry(:haaland) }
    end

    def captain
      render_with_template template: "players/player_row_component_preview/row",
                           locals: { entry: PreviewFixtures.entry(:haaland, captain: true) }
    end

    def squad_position
      render_with_template template: "players/player_row_component_preview/row",
                           locals: { entry: PreviewFixtures.entry(:gabriel, grade: "B", leading: "DF") }
    end

    def long_name
      render_with_template template: "players/player_row_component_preview/row",
                           locals: { entry: PreviewFixtures.entry(:gabriel, rank: 14, grade: "C") }
    end

    def without_team_or_photo
      render_with_template template: "players/player_row_component_preview/row",
                           locals: { entry: PreviewFixtures.entry(:unknown, rank: 212, grade: "–") }
    end
  end
end
