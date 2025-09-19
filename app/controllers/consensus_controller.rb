class ConsensusController < ApplicationController
  before_action :authenticate_user!

  def weekly
    @week = params[:week]&.to_i || current_week
    @consensus_data = PredictionAggregator.weekly_consensus_by_category(@week)
    @available_weeks = available_weeks_with_predictions
    @page_title = "Weekly Consensus - Week #{@week}"
  end

  def rest_of_season
    @consensus_data = PredictionAggregator.rest_of_season_consensus_by_category
    @page_title = "Rest of Season Consensus"
  end

  private

  def current_week
    # Use the current gameweek's fpl_id or default to 1
    current_gameweek = Gameweek.current_gameweek
    current_gameweek&.fpl_id || 1
  end

  def available_weeks_with_predictions
    # Get all weeks (gameweek fpl_ids) that have predictions
    weeks = Prediction.joins(:gameweek)
                     .where(season_type: "weekly")
                     .distinct
                     .pluck("gameweeks.fpl_id")
                     .sort

    # If no predictions exist, still show weeks 1-38 for selection
    weeks.empty? ? (1..38).to_a : weeks
  end
end
