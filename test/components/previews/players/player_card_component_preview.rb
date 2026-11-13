# frozen_string_literal: true

module Players
  class PlayerCardComponentPreview < ViewComponent::Preview
    def dark_club
      render_with_template template: "players/player_card_component_preview/card",
                           locals: { entry: PreviewFixtures.entry(:salah, rank: 2) }
    end

    def light_club
      render_with_template template: "players/player_card_component_preview/card",
                           locals: { entry: PreviewFixtures.entry(:haaland) }
    end

    def captain
      render_with_template template: "players/player_card_component_preview/card",
                           locals: { entry: PreviewFixtures.entry(:haaland, captain: true) }
    end

    def without_team_or_photo
      render_with_template template: "players/player_card_component_preview/card",
                           locals: { entry: PreviewFixtures.entry(:unknown, rank: 212, grade: "–") }
    end
  end
end
