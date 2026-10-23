module History
  class Scorecard < ApplicationService
    TOP = ForecastAccuracy::TOP
    TOP_PICKS = 11
    METRICS = %i[spearman capture rmse bias top_eleven].freeze

    def initialize(forecasts:, actuals:, positions:, relevant:)
      @forecasts = forecasts
      @actuals = actuals
      @positions = positions
      @relevant = relevant.to_set
    end

    def call
      ranking.merge(errors).merge(top_eleven: average(ranked(@forecasts.keys).first(TOP_PICKS).map { |id| actual(id) }))
    end

    def self.spearman(xs, ys)
      return nil if xs.size < 3

      pearson(ranks(xs), ranks(ys))
    end

    def self.ranks(values)
      ranks = Array.new(values.size)
      tied_groups(values).inject(0) do |start, tied|
        tied.each { |(_, index)| ranks[index] = start + (tied.size + 1) / 2.0 }
        start + tied.size
      end
      ranks
    end

    def self.tied_groups(values)
      values.each_with_index.sort_by(&:first).chunk_while { |a, b| a.first == b.first }
    end

    def self.pearson(xs, ys)
      dx = deviations(xs)
      dy = deviations(ys)
      spread = Math.sqrt(dx.sum { |d| d**2 } * dy.sum { |d| d**2 })
      return nil if spread.zero?

      dx.zip(dy).sum { |a, b| a * b } / spread
    end

    def self.deviations(values)
      mean = values.sum / values.size.to_f
      values.map { |value| value - mean }
    end

    private

    def ranking
      marks = Forecaster::POSITIONS.filter_map { |position| position_marks(players_in(position)) }
      { spearman: average(marks.filter_map { |mark| mark[:spearman] }),
        capture: average(marks.filter_map { |mark| mark[:capture] }) }
    end

    def errors
      misses = @forecasts.keys.select { |id| @relevant.include?(id) }.map { |id| forecast(id) - actual(id) }
      { rmse: Math.sqrt(average(misses.map { |miss| miss**2 })), bias: average(misses) }
    end

    def position_marks(players)
      return nil if players.size <= TOP

      relevant = players.select { |id| @relevant.include?(id) }
      { capture: capture(players),
        spearman: self.class.spearman(relevant.map { |id| forecast(id) }, relevant.map { |id| actual(id) }) }
    end

    def capture(players)
      best = players.map { |id| actual(id) }.max(TOP).sum
      return nil unless best.positive?

      ranked(players).first(TOP).sum { |id| actual(id) } / best
    end

    def players_in(position)
      @forecasts.keys.select { |id| @positions[id] == position }
    end

    def ranked(players)
      players.sort_by { |id| [ -forecast(id), id ] }
    end

    def forecast(id)
      @forecasts[id].to_f
    end

    def actual(id)
      @actuals[id].to_f
    end

    def average(values)
      return 0.0 if values.empty?

      values.sum / values.size.to_f
    end
  end
end
