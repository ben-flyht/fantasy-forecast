class ForecastersController < ApplicationController
  def index
    @rankings = ForecasterRankings.overall
    @page_title = "Forecaster Rankings"
  end

  def show
    @user = User.find(params[:id])
    @strategy = Strategy.find_by(user: @user) if @user.bot?

    # Determine the range of gameweeks to show (starting gameweek to next)
    next_gw = Gameweek.next_gameweek
    current_gw = Gameweek.current_gameweek
    starting_gw = Gameweek::STARTING_GAMEWEEK

    if next_gw
      max_gameweek = next_gw.fpl_id
      @next_gameweek_id = next_gw.fpl_id
    elsif current_gw
      max_gameweek = current_gw.fpl_id
      @next_gameweek_id = nil
    else
      max_gameweek = starting_gw # Default fallback
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
    (starting_gw...max_gameweek).each do |gw|
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

    # Fill in all gameweeks from starting gameweek to next (including next)
    @weekly_rankings = (starting_gw..max_gameweek).map do |gw|
      performance_by_gw[gw] || {
        gameweek: gw,
        total_score: 0.0,
        accuracy_score: 0.0,
        forecast_count: forecast_counts[gw] || 0,
        rank: nil
      }
    end.reverse # Descending order so starting gameweek is at bottom

    # Calculate total forecasts for overall summary
    @total_forecast_count = forecast_counts.values.sum
    @overall_rank = @overall_ranking&.dig(:rank)
    @overall_total_score = @overall_ranking&.dig(:total_score) || 0.0
    @overall_accuracy_score = @overall_ranking&.dig(:accuracy_score) || 0.0

    @page_title = "#{@user.username}'s Forecasts"
  end

  def gameweeks
    @user = User.find(params[:id])
    @gameweek = params[:gameweek]&.to_i
    @next_gameweek_id = Gameweek.next_gameweek&.fpl_id

    # Get all forecasts for this user and gameweek, grouped by position
    all_forecasts = ForecasterRankings.weekly_forecasts(@user.id, @gameweek)

    # Get all performances for this gameweek to calculate ranks
    gameweek_record = Gameweek.find_by(fpl_id: @gameweek)

    # Preload matches for opponent component to avoid N+1
    if gameweek_record
      @matches_by_team = Hash.new { |h, k| h[k] = [] }
      Match.includes(:home_team, :away_team)
           .where(gameweek: gameweek_record)
           .each do |match|
        @matches_by_team[match.home_team_id] << match
        @matches_by_team[match.away_team_id] << match
      end
    else
      @matches_by_team = {}
    end
    if gameweek_record
      performances = Performance.includes(player: :team)
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

    # Get gameweek scores from the service (single source of truth)
    gameweek_performance = ForecasterRankings.weekly_performance(@user.id).find { |w| w[:gameweek] == @gameweek }

    if gameweek_performance
      @forecast_count = gameweek_performance[:forecast_count]
      @avg_total_score = gameweek_performance[:total_score]
      @avg_accuracy_score = gameweek_performance[:accuracy_score]
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
