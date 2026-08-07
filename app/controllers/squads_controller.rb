# The best fifteen the budget buys, read from what the hourly run wrote down.
#
# Nothing is optimised here. If the search has not run yet there is no squad to show,
# which is the honest answer rather than making somebody wait nine seconds for one.
class SquadsController < ApplicationController
  include ServesCards

  SEASON = "season".freeze

  def show
    @horizon = Squad::HORIZONS.include?(params[:horizon]) ? params[:horizon] : "gameweek"
    @gameweek = Gameweek.next_gameweek
    @squad = Squad.find_by(gameweek: @gameweek, horizon: @horizon)
    @forecast_at = @squad&.updated_at

    load_squad_players if @squad

    respond_to do |format|
      format.html
      format.png { render_card }
    end
  end

  private

  def load_squad_players
    @players = Player.includes(:team).where(id: @squad.player_ids).index_by(&:id)
  end

  # A week with no squad has no picture of one, and saying so is better than sending
  # a card that has to explain itself.
  def render_card
    return head :not_found unless @squad

    send_card("cards/squad", card_key)
  end

  def card_key
    [ "squad_card", @horizon, @gameweek&.id, @squad.updated_at.to_i ].join("/")
  end

  def horizon = @horizon_read ||= Horizon.find(@horizon)

  def season? = horizon.season?
  helper_method :season?

  def horizon_label = horizon.label(gameweek: @gameweek&.fpl_id)
  helper_method :horizon_label

  # The address this squad is at, and the address its card is at.
  def squad_url(format: nil, reach: horizon)
    case reach.to_s
    when Horizon::SEASON then season_squad_path(format: format)
    when Horizon::UPCOMING then upcoming_squad_path(format: format)
    else squad_path(format: format)
    end
  end
  helper_method :squad_url
end
