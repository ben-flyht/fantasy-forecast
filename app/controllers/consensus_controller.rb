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
    # Default to week 1, but this could be calculated based on current date
    # or stored in application settings
    1
  end

  def available_weeks_with_predictions
    # Get all weeks that have predictions
    weeks = Prediction.where(season_type: "weekly")
                     .where.not(week: nil)
                     .distinct
                     .pluck(:week)
                     .sort

    # If no predictions exist, still show weeks 1-38 for selection
    weeks.empty? ? (1..38).to_a : weeks
  end
end
