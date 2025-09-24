class UsersController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @rankings = ForecasterRankings.overall
    @page_title = "Forecaster Rankings"
  end

  def show
    @user = User.find(params[:id])
    @is_own_profile = user_signed_in? && current_user.id == @user.id
    @weekly_performance = ForecasterRankings.weekly_performance(@user.id, limit: 20)
    @overall_stats = ForecasterRankings.overall.find { |r| r[:user_id] == @user.id }
    @page_title = @is_own_profile ? "My Profile" : "#{@user.username} - Forecaster Profile"

    # Calculate some additional stats
    if @weekly_performance.any?
      scores = @weekly_performance.map { |w| w[:total_score] }
      @best_week = @weekly_performance.max_by { |w| w[:total_score] }
      @worst_week = @weekly_performance.min_by { |w| w[:total_score] }
      @avg_weekly_score = (scores.sum / scores.size).round(2)
      @recent_form = @weekly_performance.first(5).map { |w| w[:total_score] }.sum.round(2)
    end

    # If viewing own profile, add forecast creation data
    if @is_own_profile
      @current_gameweek = Gameweek.next_gameweek
      if @current_gameweek
        # Load players with their total scores pre-calculated and ordered by score
        players_with_scores = Player.joins("LEFT JOIN performances ON performances.player_id = players.id")
                                    .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                    .group("players.id")
                                    .order("total_score_cached DESC, first_name, last_name")
        @players_by_position = players_with_scores.group_by(&:position)

        # Get current user's forecasts for the current gameweek
        @current_forecasts = current_user.forecasts
                                        .includes(:player)
                                        .where(gameweek: @current_gameweek)
                                        .order(:id)
                                        .group_by(&:category)
      else
        @current_forecasts = { "target" => [], "avoid" => [] }
      end
    end
  end

  def weekly_forecasts
    @user = User.find(params[:id])
    @week = params[:week]&.to_i
    @forecasts = ForecasterRankings.weekly_forecasts(@user.id, @week)
    @page_title = "#{@user.username} - Week #{@week} Forecasts"

    # Calculate week totals
    if @forecasts.any?
      @week_total = @forecasts.sum { |f| f[:total_score] }
      @week_accuracy = @forecasts.sum { |f| f[:accuracy_score] }
      @week_contrarian = @forecasts.sum { |f| f[:contrarian_bonus] }
    end
  end
end
