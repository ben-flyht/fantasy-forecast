# frozen_string_literal: true

module Play
  class PackCardComponentPreview < ViewComponent::Preview
    def plain
      render_with_template template: "play/pack_card_component_preview/cards",
                           locals: { cards: [ { card: PreviewFixtures.card(:salah) }, { card: PreviewFixtures.card(:haaland) } ] }
    end

    def shiny
      render_with_template template: "play/pack_card_component_preview/cards",
                           locals: { cards: [ { card: PreviewFixtures.card(:saka), shiny: true } ] }
    end

    def captain
      render_with_template template: "play/pack_card_component_preview/cards",
                           locals: { cards: [ { card: PreviewFixtures.card(:haaland), captain: true } ] }
    end

    def scored
      render_with_template template: "play/pack_card_component_preview/cards",
                           locals: { cards: [ { card: PreviewFixtures.card(:palmer), points: "6 pts" } ] }
    end

    def choice
      render_with_template template: "play/pack_card_component_preview/cards",
                           locals: { cards: [ { card: PreviewFixtures.card(:gabriel), href: "#" },
                                              { card: PreviewFixtures.card(:pope, fixtures: []), href: "#" } ] }
    end

    def small
      render_with_template template: "play/pack_card_component_preview/cards",
                           locals: { cards: [ { card: PreviewFixtures.card(:salah), size: :small } ] }
    end
  end
end
