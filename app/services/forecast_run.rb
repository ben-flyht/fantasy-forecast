class ForecastRun < ApplicationService
  Result = Struct.new(:outcomes, keyword_init: true) do
    def total_forecasts
      outcomes.sum { |outcome| outcome[:count] }
    end

    def failures
      outcomes.select { |outcome| outcome[:error] }
    end

    def ok?
      failures.empty?
    end
  end

  def initialize(gameweek:, strategies: nil, **)
    @gameweek = gameweek
    @strategies = strategies || Strategy.active
  end

  def call
    Result.new(outcomes: @strategies.map { |strategy| run(strategy) })
  end

  private

  def run(strategy)
    forecasts = strategy.generate_forecasts(@gameweek, generate_explanations: false)
    { position: label(strategy), count: forecasts.count, error: nil }
  rescue StandardError => e
    Rails.logger.error("ForecastRun failed for #{label(strategy)}: #{e.class}: #{e.message}")
    { position: label(strategy), count: 0, error: e }
  end

  def label(strategy)
    strategy.position_specific? ? strategy.position : "all positions"
  end
end
