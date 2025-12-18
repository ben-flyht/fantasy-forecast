class ForecastersController < ApplicationController
  def index
    @rankings = ForecasterRankings.overall
    @page_title = "Forecaster Rankings"
  end

  def show
    @user = User.find(params[:id])
    load_gameweek_range
    load_weekly_rankings
    load_overall_summary
    @page_title = "#{@user.username}'s Forecasts"
  end

  def gameweeks
    @user = User.find(params[:id])
    @gameweek = params[:gameweek]&.to_i
    @next_gameweek_id = Gameweek.next_gameweek&.fpl_id

    load_forecasts_with_ranks
    load_gameweek_performance
    load_gameweek_ranking
    @page_title = "#{@user.username} - Gameweek #{@gameweek} Forecasts"
  end

  private

  def load_gameweek_range
    next_gw = Gameweek.next_gameweek
    current_gw = Gameweek.current_gameweek

    @next_gameweek_id = next_gw&.fpl_id
    @max_gameweek = next_gw&.fpl_id || current_gw&.fpl_id || Gameweek::STARTING_GAMEWEEK
  end

  def load_weekly_rankings
    performance_by_gw = build_performance_by_gameweek
    forecast_counts = fetch_forecast_counts
    add_ranks_to_performance(performance_by_gw)

    @weekly_rankings = build_weekly_rankings(performance_by_gw, forecast_counts)
    @total_forecast_count = forecast_counts.values.sum
  end

  def build_performance_by_gameweek
    ForecasterRankings.weekly_performance(@user.id).index_by { |p| p[:gameweek] }
  end

  def fetch_forecast_counts
    Forecast.joins(:gameweek).where(user_id: @user.id).group("gameweeks.fpl_id").count
  end

  def add_ranks_to_performance(performance_by_gw)
    (Gameweek::STARTING_GAMEWEEK...@max_gameweek).each do |gw|
      gameweek_rankings = ForecasterRankings.for_gameweek(gw)
      user_ranking = gameweek_rankings.find { |r| r[:user_id] == @user.id }
      next unless performance_by_gw[gw] && user_ranking

      performance_by_gw[gw][:rank] = user_ranking[:rank]
      performance_by_gw[gw][:total_forecasters] = gameweek_rankings.size
    end
  end

  def build_weekly_rankings(performance_by_gw, forecast_counts)
    (Gameweek::STARTING_GAMEWEEK..@max_gameweek).map do |gw|
      performance_by_gw[gw] || { gameweek: gw, accuracy_score: 0.0, forecast_count: forecast_counts[gw] || 0, rank: nil }
    end.reverse
  end

  def load_overall_summary
    overall_rankings = ForecasterRankings.overall
    @overall_ranking = overall_rankings.find { |r| r[:user_id] == @user.id }
    @total_forecasters = overall_rankings.size
    @overall_rank = @overall_ranking&.dig(:rank)
    @overall_accuracy_score = @overall_ranking&.dig(:accuracy_score) || 0.0
  end

  def load_forecasts_with_ranks
    all_forecasts = ForecasterRankings.weekly_forecasts(@user.id, @gameweek)
    gameweek_record = Gameweek.find_by(fpl_id: @gameweek)

    @matches_by_team = build_matches_by_team(gameweek_record)
    add_position_ranks_to_forecasts(all_forecasts, gameweek_record)
    @forecasts_by_position = all_forecasts.group_by { |f| f.player.position }
  end

  def build_matches_by_team(gameweek_record)
    return {} unless gameweek_record

    matches = Hash.new { |h, k| h[k] = [] }
    Match.includes(:home_team, :away_team).where(gameweek: gameweek_record).each do |match|
      matches[match.home_team_id] << match
      matches[match.away_team_id] << match
    end
    matches
  end

  def add_position_ranks_to_forecasts(forecasts, gameweek_record)
    return unless gameweek_record

    position_ranks = calculate_position_ranks(gameweek_record)
    forecasts.each do |forecast|
      next unless position_ranks[forecast.player_id]

      rank_data = position_ranks[forecast.player_id]
      forecast.define_singleton_method(:position_rank) { rank_data[:rank] }
      forecast.define_singleton_method(:position_total) { rank_data[:total] }
    end
  end

  def calculate_position_ranks(gameweek_record)
    performances = Performance.includes(player: :team).where(gameweek_id: gameweek_record.id)
    position_ranks = {}

    performances.group_by { |p| p.player.position }.each do |_position, perfs|
      perfs.sort_by(&:gameweek_score).reverse.each_with_index do |perf, index|
        position_ranks[perf.player_id] = { rank: index + 1, total: perfs.size }
      end
    end

    position_ranks
  end

  def load_gameweek_performance
    gameweek_performance = ForecasterRankings.weekly_performance(@user.id).find { |w| w[:gameweek] == @gameweek }

    if gameweek_performance
      @forecast_count = gameweek_performance[:forecast_count]
      @avg_accuracy_score = gameweek_performance[:accuracy_score]
    else
      @forecast_count = 0
      @avg_accuracy_score = nil
    end
  end

  def load_gameweek_ranking
    gameweek_rankings = ForecasterRankings.for_gameweek(@gameweek)
    user_ranking = gameweek_rankings.find { |r| r[:user_id] == @user.id }
    return unless user_ranking

    @gameweek_rank = user_ranking[:rank]
    @gameweek_total_forecasters = gameweek_rankings.size
  end
end
