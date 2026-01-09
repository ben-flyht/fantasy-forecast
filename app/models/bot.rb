# Tabless model representing the forecasting bot.
# The bot doesn't need a database record - it just uses strategies from the database.
class Bot
  BOT_NAME = "ForecasterBot".freeze

  class << self
    def name
      BOT_NAME
    end

    def strategies
      Strategy.active
    end

    def strategy_for_position(position)
      Strategy.active.find_by(position: position) || Strategy.active.find_by(position: nil)
    end

    def forecasts
      Forecast.all
    end
  end
end
