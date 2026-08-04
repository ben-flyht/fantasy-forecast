# frozen_string_literal: true

# The banner at the top of a player's page. It says who he is; the panel beneath
# it says how he is rated, so no rank or grade appears here.
class PlayerHeroComponent < PlayerRowComponent
  def initialize(player:, facts:)
    super(ranking: nil, player: player, facts: facts)
  end

  private

  def details
    [
      [ "Position", player.position&.capitalize ],
      [ "Club", team&.name ],
      [ "Cost", cost ],
      [ "Ownership", ownership ]
    ].reject { |_label, value| value.blank? }
  end

  def badge_silhouette
    team.on_light? ? "brightness-0" : "brightness-0 invert"
  end
end
