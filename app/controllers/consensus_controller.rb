class ConsensusController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @week = params[:week]&.to_i || current_week
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
    # Default to week 5 as requested
    5
  end

  def available_weeks_with_forecasts
    # Get all weeks (gameweek fpl_ids) that have forecasts
    weeks = Forecast.joins(:gameweek)
                     .distinct
                     .pluck("gameweeks.fpl_id")
                     .sort

    # If no forecasts exist, still show weeks 1-38 for selection
    weeks.empty? ? (1..38).to_a : weeks
  end
end
