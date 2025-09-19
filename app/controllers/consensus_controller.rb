class ConsensusController < ApplicationController
  before_action :authenticate_user!

  def index
    @week = params[:week]&.to_i || current_week
    @position_filter = params[:position]

    # Map display position to database position
    db_position_filter = case @position_filter
    when "GK" then "goalkeeper"
    when "DEF" then "defender"
    when "MID" then "midfielder"
    when "FWD" then "forward"
    else @position_filter
    end

    # Get consensus scores for the week with optional position filtering
    @consensus_rankings = Prediction.consensus_scores_for_week_by_position(@week, db_position_filter)

    @available_weeks = available_weeks_with_predictions
    @available_positions = ["GK", "DEF", "MID", "FWD"]
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

  def available_weeks_with_predictions
    # Get all weeks (gameweek fpl_ids) that have predictions
    weeks = Prediction.joins(:gameweek)
                     .distinct
                     .pluck("gameweeks.fpl_id")
                     .sort

    # If no predictions exist, still show weeks 1-38 for selection
    weeks.empty? ? (1..38).to_a : weeks
  end
end
