class ForecastScoreCalculator < ApplicationService
  def initialize(gameweek)
    @gameweek = gameweek.is_a?(Gameweek) ? gameweek : Gameweek.find(gameweek)
    @gameweek_id = @gameweek.id
    @gameweek_fpl_id = @gameweek.fpl_id
  end

  def call
    load_data
    process_forecasts
  end

  private

  def load_data
    @forecasts = Forecast.includes(:player, :user).where(gameweek_id: @gameweek_id).to_a
    @performances = Performance.includes(:player).where(gameweek_id: @gameweek_id).index_by(&:player_id)
    @scorable_forecast_ids = build_scorable_forecast_ids
    @scorable_forecasts = @forecasts.select { |f| @scorable_forecast_ids.include?(f.id) }
  end

  def build_scorable_forecast_ids
    bot_ids = Forecast.scorable_bot_forecasts(@forecasts, @gameweek_fpl_id)
    human_ids = Forecast.scorable_human_forecasts(@forecasts, @performances)
    bot_ids + human_ids
  end

  def process_forecasts
    @forecasts.each { |forecast| process_forecast(forecast) }
  end

  def process_forecast(forecast)
    unless @scorable_forecast_ids.include?(forecast.id)
      forecast.update!(accuracy: nil) if forecast.accuracy.present?
      return
    end

    performance = @performances[forecast.player_id]
    return unless performance

    accuracy = ForecastAccuracyCalculator.call(forecast, @scorable_forecasts, @performances)
    forecast.update!(accuracy: accuracy)
  end
end
