class ForecastersController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @rankings = ForecasterRankings.overall
    @page_title = "Forecaster Rankings"
  end

  def show
    @user = User.find(params[:id])

    # Determine the range of gameweeks to show (1 to next)
    next_gw = Gameweek.next_gameweek
    current_gw = Gameweek.current_gameweek

    if next_gw
      max_gameweek = next_gw.fpl_id
      @next_gameweek_id = next_gw.fpl_id
    elsif current_gw
      max_gameweek = current_gw.fpl_id
      @next_gameweek_id = nil
    else
      max_gameweek = 8 # Default fallback
      @next_gameweek_id = nil
    end

    # Get all weekly performance for this forecaster
    user_performance = ForecasterRankings.weekly_performance(@user.id)
    performance_by_gw = user_performance.index_by { |p| p[:gameweek] }

    # Get forecast counts for all gameweeks (including unscored)
    forecast_counts = Forecast.joins(:gameweek)
                              .where(user_id: @user.id)
                              .group("gameweeks.fpl_id")
                              .count

    # Get rankings for each gameweek to add rank
    (1...max_gameweek).each do |gw|
      gameweek_rankings = ForecasterRankings.for_gameweek(gw)
      user_ranking = gameweek_rankings.find { |r| r[:user_id] == @user.id }
      if performance_by_gw[gw] && user_ranking
        performance_by_gw[gw][:rank] = user_ranking[:rank]
        performance_by_gw[gw][:total_forecasters] = gameweek_rankings.size
      end
    end

    # Get overall ranking for summary
    overall_rankings = ForecasterRankings.overall
    @overall_ranking = overall_rankings.find { |r| r[:user_id] == @user.id }
    @total_forecasters = overall_rankings.size

    # Fill in all gameweeks from 1 to next (including next)
    @weekly_rankings = (1..max_gameweek).map do |gw|
      performance_by_gw[gw] || {
        gameweek: gw,
        total_score: 0.0,
        accuracy_score: 0.0,
        availability_score: 0.0,
        forecast_count: forecast_counts[gw] || 0,
        rank: nil
      }
    end.reverse # Descending order so gameweek 1 is at bottom

    # Calculate total forecasts for overall summary
    @total_forecast_count = forecast_counts.values.sum
    @overall_rank = @overall_ranking&.dig(:rank)
    @overall_total_score = @overall_ranking&.dig(:total_score) || 0.0

    @page_title = "#{@user.username}'s Forecasts"
  end

  def gameweeks
    @user = User.find(params[:id])
    @gameweek = params[:gameweek]&.to_i

    # Get all forecasts for this user and gameweek, grouped by position
    all_forecasts = ForecasterRankings.weekly_forecasts(@user.id, @gameweek)

    # Get all performances for this gameweek to calculate ranks
    gameweek_record = Gameweek.find_by(fpl_id: @gameweek)
    if gameweek_record
      performances = Performance.includes(:player)
                                .where(gameweek_id: gameweek_record.id)
                                .order(gameweek_score: :desc)

      # Calculate rank by position
      position_ranks = {}
      performances.group_by { |p| p.player.position }.each do |position, position_perfs|
        position_perfs.sort_by(&:gameweek_score).reverse.each_with_index do |perf, index|
          position_ranks[perf.player_id] = {
            rank: index + 1,
            total: position_perfs.size
          }
        end
      end

      # Add rank info to each forecast
      all_forecasts.each do |forecast|
        if position_ranks[forecast.player_id]
          forecast.define_singleton_method(:position_rank) { position_ranks[forecast.player_id][:rank] }
          forecast.define_singleton_method(:position_total) { position_ranks[forecast.player_id][:total] }
        end
      end
    end

    @forecasts_by_position = all_forecasts.group_by { |f| f.player.position }

    # Calculate gameweek scores (matching forecasters table)
    if all_forecasts.any?
      @forecast_count = all_forecasts.size

      # Only calculate averages if there are scored forecasts
      scored_forecasts = all_forecasts.select { |f| f.accuracy.present? }
      if scored_forecasts.any?
        @avg_total_score = scored_forecasts.sum { |f| f.total_score.to_f } / scored_forecasts.size
        @avg_accuracy_score = scored_forecasts.sum { |f| f.accuracy.to_f } / scored_forecasts.size
      else
        @avg_total_score = nil
        @avg_accuracy_score = nil
      end
    else
      @forecast_count = 0
      @avg_total_score = nil
      @avg_accuracy_score = nil
    end

    # Get rank for this gameweek
    gameweek_rankings = ForecasterRankings.for_gameweek(@gameweek)
    user_ranking = gameweek_rankings.find { |r| r[:user_id] == @user.id }
    if user_ranking
      @gameweek_rank = user_ranking[:rank]
      @gameweek_total_forecasters = gameweek_rankings.size
    end

    @page_title = "#{@user.username} - Gameweek #{@gameweek} Forecasts"
  end
end
