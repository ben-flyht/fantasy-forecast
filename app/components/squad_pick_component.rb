# frozen_string_literal: true

# One player in the squad. The rankings answer "who is best?" and lead with a rank and
# a grade; this answers "why is he in the team?" and leads with what he costs and what
# he is expected to return, because those are the two numbers the budget is spent on.
class SquadPickComponent < ViewComponent::Base
  POSITION_LABELS = {
    "goalkeeper" => "GK", "defender" => "DEF", "midfielder" => "MID", "forward" => "FWD"
  }.freeze

  def initialize(pick:, player:, captain: false, order: nil)
    @pick = pick
    @player = player
    @captain = captain
    @order = order
  end

  private

  attr_reader :pick, :player, :captain, :order

  def position_label = POSITION_LABELS.fetch(pick["position"], "?")

  def team = player.team

  def color = team&.color || Team::DEFAULT_COLOR

  def text_class = team&.on_light? ? "text-zinc-900" : "text-white"

  def cost = helpers.player_price(pick["cost"])

  def expected_points = format("%.1f", pick["expected_points"].to_f)

  def captain? = captain
end
