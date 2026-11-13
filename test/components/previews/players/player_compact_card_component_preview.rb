# frozen_string_literal: true

module Players
  class PlayerCompactCardComponentPreview < ViewComponent::Preview
    def pair
      render_with_template locals: { entries: [
        PreviewFixtures.entry(:haaland, leading: "7.4"), PreviewFixtures.entry(:salah, grade: "B", leading: "6.9")
      ] }
    end

    def without_forecast
      render_with_template template: "players/player_compact_card_component_preview/pair", locals: { entries: [
        PreviewFixtures.entry(:saka, leading: "6.1"), PreviewFixtures.entry(:unknown, grade: "–", leading: "—")
      ] }
    end
  end
end
