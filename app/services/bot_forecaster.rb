class BotForecaster < ApplicationService
  attr_reader :user, :gameweek, :strategy_config

  def initialize(user:, strategy_config:, gameweek:)
    @user = user
    @strategy_config = strategy_config
    @gameweek = gameweek
  end

  def call
    raise ArgumentError, "User must be a bot" unless user.bot?
    raise ArgumentError, "No gameweek available" unless gameweek

    clear_existing_forecasts

    forecasts = []

    FantasyForecast::POSITION_CONFIG.each do |position, config|
      slots = config[:slots]
      selected_players = StrategyRunner.call(strategy_config, position:, count: slots, gameweek:)

      selected_players.each do |player|
        forecasts << create_forecast(player)
      end
    end

    forecasts
  end

  private

  def clear_existing_forecasts
    Forecast.where(user:, gameweek:).destroy_all
  end

  def create_forecast(player)
    Forecast.create!(user:, player:, gameweek:)
  end
end
