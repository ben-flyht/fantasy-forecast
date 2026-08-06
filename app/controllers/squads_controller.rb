# The best fifteen the budget buys, read from what the hourly run wrote down.
#
# Nothing is optimised here. If the search has not run yet there is no squad to show,
# which is the honest answer rather than making somebody wait nine seconds for one.
class SquadsController < ApplicationController
  def show
    @horizon = Squad::HORIZONS.include?(params[:horizon]) ? params[:horizon] : "gameweek"
    @gameweek = Gameweek.next_gameweek
    @squad = Squad.find_by(gameweek: @gameweek, horizon: @horizon)

    load_squad_players if @squad
  end

  private

  def load_squad_players
    @players = Player.includes(:team).where(id: @squad.player_ids).index_by(&:id)
  end

  def horizon_label = @horizon == "season" ? "Rest of Season" : "Gameweek #{@gameweek&.fpl_id}"
  helper_method :horizon_label
end
