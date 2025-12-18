class ForecastAccuracyCalculator < ApplicationService
  def initialize(forecast, all_forecasts, performances)
    @forecast = forecast
    @all_forecasts = all_forecasts
    @performances = performances
  end

  def call
    return 0.0 unless current_performance

    unique_scores = position_unique_scores
    return 0.0 if unique_scores.size <= 1

    rank = unique_scores.index(current_score) + 1
    (unique_scores.size - rank).to_f / (unique_scores.size - 1)
  end

  private

  def current_performance
    @current_performance ||= @performances[@forecast.player_id]
  end

  def current_score
    current_performance.gameweek_score
  end

  def current_position
    @forecast.player.position
  end

  def position_unique_scores
    position_performances.map(&:gameweek_score).uniq.sort.reverse
  end

  def position_performances
    @performances.values.select do |perf|
      perf.player.position == current_position && !excluded_player_ids.include?(perf.player_id)
    end
  end

  def excluded_player_ids
    @excluded_player_ids ||= @all_forecasts
      .select { |f| f.user_id == @forecast.user_id && f.player.position == current_position && f.player_id != @forecast.player_id }
      .map(&:player_id)
  end
end
