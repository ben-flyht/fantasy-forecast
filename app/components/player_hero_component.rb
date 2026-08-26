# frozen_string_literal: true

# The banner at the top of a player's page. It says who he is; the panel beneath
# it says how he is rated, so no rank or grade appears here.
class PlayerHeroComponent < PlayerRowComponent
  def initialize(player:, facts:, duties: [])
    @duties = duties
    super(ranking: nil, player: player, facts: facts)
  end

  private

  attr_reader :duties

  # Who he is, in the order a reader asks it. Dead balls come last because they
  # are the only line that is often empty, and a fact that comes and goes should
  # not move the ones beside it.
  def details
    [
      [ "Position", player.position&.capitalize ],
      [ "Club", team&.name ],
      [ "Age", player.age ],
      [ "Cost", cost ],
      [ "Ownership", ownership ],
      [ "Set pieces", dead_balls ]
    ].reject { |_label, value| value.blank? }
  end

  # The dead balls he actually takes.
  #
  # They belong with the facts about the man rather than in a strip of their own,
  # being the one thing among them that reliably moves a forecast: whoever takes
  # the penalties is a penalty a game ahead of whoever does not.
  #
  # Only where he is first choice, though, which is the whole of that argument. A
  # deputy takes none until somebody is hurt, and saying so at length costs more
  # than it tells: Kluivert read "Penalties (2nd), Free kicks (2nd), Corners
  # (3rd)" and ran the line out across his own photograph. The deputies are on
  # the comparison page, where there is a column to hold them.
  def dead_balls
    duties.select(&:first_choice?).map(&:name).join(", ").presence
  end

  def badge_silhouette
    team.on_light? ? "brightness-0" : "brightness-0 invert"
  end
end
