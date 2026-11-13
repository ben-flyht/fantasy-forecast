# frozen_string_literal: true

module Elements
  class ChipLinksComponentPreview < ViewComponent::Preview
    def comparisons
      render ChipLinksComponent.new(links: [
        [ "Haaland or Salah?", "#" ], [ "Saka or Palmer?", "#" ], [ "Gabriel or Saliba?", "#" ],
        [ "Haaland and Saka, or Salah and Palmer?", "#" ]
      ])
    end

    def labelled_navigation
      render ChipLinksComponent.new(label: "FPL rankings by position", links: %w[goalkeepers defenders midfielders forwards].map { |position|
        [ "Best FPL #{position} this week", "#" ]
      })
    end
  end
end
