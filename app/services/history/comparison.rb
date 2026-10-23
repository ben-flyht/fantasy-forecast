module History
  class Comparison < ApplicationService
    HIGHER_IS_BETTER = { spearman: true, capture: true, top_eleven: true, rmse: false }.freeze
    RESAMPLES = 2000
    SEED = 2526

    def initialize(base, candidate, block: 1)
      @rounds = base.keys & candidate.keys
      @base = base
      @candidate = candidate
      @block = block
    end

    def call
      Scorecard::METRICS.to_h do |metric|
        [ metric, { base: mean(@base, metric), candidate: mean(@candidate, metric),
                    better: better_chance(metric) } ]
      end
    end

    def self.summary(scores)
      Scorecard::METRICS.to_h { |metric| [ metric, scores.values.sum { |score| score[metric] } / scores.size ] }
    end

    def self.spread(scores, metric)
      values = scores.values.map { |score| score[metric] }
      mean = values.sum / values.size
      Math.sqrt(values.sum { |value| (value - mean)**2 } / (values.size - 1)) / Math.sqrt(values.size)
    end

    private

    def mean(scores, metric)
      @rounds.sum { |round| scores[round][metric] } / @rounds.size
    end

    def better_chance(metric)
      return nil unless HIGHER_IS_BETTER.key?(metric)

      gains = @rounds.map { |round| gain(round, metric) }
      random = Random.new(SEED)
      wins = Array.new(RESAMPLES) { resample(gains, random).sum.positive? ? 1 : 0 }.sum
      wins / RESAMPLES.to_f
    end

    def gain(round, metric)
      difference = @candidate[round][metric] - @base[round][metric]
      HIGHER_IS_BETTER[metric] ? difference : -difference
    end

    def resample(gains, random)
      blocks = (gains.size / @block.to_f).ceil
      Array.new(blocks) do
        start = random.rand(gains.size - @block + 1)
        gains[start, @block]
      end.flatten
    end
  end
end
