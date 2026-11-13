# frozen_string_literal: true

module Players
  class PlayerHeroComponentPreview < ViewComponent::Preview
    def dark_club
      render hero(:salah, duties: [ PlayerProfile::Duty.new(name: "Penalties", order: 1) ])
    end

    def light_club
      render hero(:haaland, duties: [ PlayerProfile::Duty.new(name: "Penalties", order: 1),
                                      PlayerProfile::Duty.new(name: "Free kicks", order: 2) ])
    end

    def long_name
      render hero(:gabriel)
    end

    private

    def hero(key, duties: [])
      PlayerHeroComponent.new(player: PreviewFixtures.player(key), facts: PreviewFixtures.facts(key), duties: duties)
    end
  end
end
