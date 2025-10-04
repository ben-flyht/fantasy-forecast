class ForecastersController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @gameweek = params[:gameweek]

    if @gameweek.present?
      @rankings = ForecasterRankings.for_gameweek(@gameweek.to_i)
      @page_title = "Forecaster Rankings - Gameweek #{@gameweek}"
    else
      @rankings = ForecasterRankings.overall
      @page_title = "Forecaster Rankings"
    end

    # Get available gameweeks (all up to current, excluding next)
    next_gw = Gameweek.next_gameweek
    current_gw = Gameweek.current_gameweek

    if next_gw
      # Show all gameweeks from 1 to current (next - 1)
      @available_gameweeks = (1...(next_gw.fpl_id)).to_a.reverse
    elsif current_gw
      # Fallback to current if no next gameweek
      @available_gameweeks = (1..current_gw.fpl_id).to_a.reverse
    else
      # Fallback: show gameweeks that have forecasts, or 1-38 if none
      gameweeks = Forecast.joins(:gameweek)
                       .distinct
                       .pluck("gameweeks.fpl_id")
                       .sort.reverse
      @available_gameweeks = gameweeks.empty? ? (1..38).to_a.reverse : gameweeks
    end
  end

  def show
    redirect_to edit_user_registration_path
  end

  def gameweeks
    @user = User.find(params[:id])
    @gameweek = params[:gameweek]&.to_i
    @forecasts = ForecasterRankings.weekly_forecasts(@user.id, @gameweek)
    @page_title = "#{@user.username} - Gameweek #{@gameweek} Forecasts"

    # Calculate gameweek totals
    if @forecasts.any?
      @gameweek_total = @forecasts.sum { |f| f[:total_score] }
      @gameweek_accuracy = @forecasts.sum { |f| f[:accuracy_score] }
      @gameweek_differential = @forecasts.sum { |f| f[:differential_score] }
    end
  end
end
