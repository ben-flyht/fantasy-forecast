class ConsensusController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @week = params[:week].present? ? params[:week].to_i : current_week
    @position_filter = params[:position] || "forward"  # Default to forward if no position specified

    # Get consensus scores for the week with position filtering
    @consensus_rankings = ConsensusRanking.for_week_and_position(@week, @position_filter)

    @available_weeks = available_weeks_with_forecasts
    @available_positions = ["goalkeeper", "defender", "midfielder", "forward"]
    @page_title = "Weekly Consensus Rankings - Week #{@week}"
    @page_title += " (#{@position_filter.capitalize}s)" if @position_filter.present?
  end

  private

  def current_week
    # Use the current gameweek from the database, fallback to 1 if none set
    Gameweek.current_gameweek&.fpl_id || 1
  end

  def available_weeks_with_forecasts
    current_gw = Gameweek.current_gameweek

    if current_gw
      # Show all weeks from 1 to current gameweek
      (1..current_gw.fpl_id).to_a.reverse
    else
      # Fallback: show weeks that have forecasts, or 1-38 if none
      weeks = Forecast.joins(:gameweek)
                       .distinct
                       .pluck("gameweeks.fpl_id")
                       .sort.reverse
      weeks.empty? ? (1..38).to_a.reverse : weeks
    end
  end
end
