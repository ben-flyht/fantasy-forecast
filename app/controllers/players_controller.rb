class PlayersController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @gameweek = params[:gameweek].present? ? params[:gameweek].to_i : current_gameweek
    @position_filter = params[:position] || "forward"  # Default to forward if no position specified

    # Get consensus scores for the gameweek with position filtering
    @consensus_rankings = ConsensusRanking.for_week_and_position(@gameweek, @position_filter)

    @available_gameweeks = available_gameweeks_with_forecasts
    @available_positions = [ "goalkeeper", "defender", "midfielder", "forward" ]
    @page_title = "Weekly Consensus Rankings - Gameweek #{@gameweek}"
    @page_title += " (#{@position_filter.capitalize}s)" if @position_filter.present?
  end

  private

  def current_gameweek
    # Use the next gameweek (what we're forecasting for), fallback to current if no next, then 1
    Gameweek.next_gameweek&.fpl_id || Gameweek.current_gameweek&.fpl_id || 1
  end

  def available_gameweeks_with_forecasts
    next_gw = Gameweek.next_gameweek
    current_gw = Gameweek.current_gameweek

    if next_gw
      # Show all gameweeks from 1 to next gameweek (what we're forecasting for)
      (1..next_gw.fpl_id).to_a.reverse
    elsif current_gw
      # Fallback to current if no next gameweek
      (1..current_gw.fpl_id).to_a.reverse
    else
      # Fallback: show gameweeks that have forecasts, or 1-38 if none
      gameweeks = Forecast.joins(:gameweek)
                       .distinct
                       .pluck("gameweeks.fpl_id")
                       .sort.reverse
      gameweeks.empty? ? (1..38).to_a.reverse : gameweeks
    end
  end
end
