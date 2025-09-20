class ConsensusController < ApplicationController
  before_action :authenticate_user!

  def index
    @week = params[:week]&.to_i || current_week
    @position_filter = params[:position]

    # Get consensus scores for the week with optional position filtering
    @consensus_rankings = Forecast.consensus_scores_for_week_by_position(@week, @position_filter)

    @available_weeks = available_weeks_with_forecasts
    @available_positions = ["goalkeeper", "defender", "midfielder", "forward"]
    @page_title = "Weekly Consensus Rankings - Week #{@week}"
    @page_title += " (#{@position_filter})" if @position_filter.present?
  end

  # Keep weekly for backwards compatibility
  alias_method :weekly, :index

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
