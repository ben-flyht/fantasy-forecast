# frozen_string_literal: true

# The arithmetic behind a forecast, in English.
#
# Every site publishes a number. This one publishes how it got there, which is
# the only thing that makes the number worth acting on. The figures come from
# Forecast#working exactly as ExpectedPoints left them; naming them and reading
# them aloud is this component's whole job.
#
# One thing it must not do is imply an equation that does not hold. A forecast is
# the per-game estimate multiplied by the fixtures, the transfer momentum, how
# fit the player is and, for a goalkeeper, his share of his club's one place. The
# last two are not in the stored working, so these figures are presented as the
# pieces they are rather than totted up to the score above them. Form is a
# further trap: it is applied inside the points-per-90 rate, not on top of the
# finished number, so it is shown as part of that rate and never as a multiplier.
class ForecastWorkingComponent < ViewComponent::Base
  # A factor this close to one is rounding, not an argument.
  NEGLIGIBLE = 0.005

  # Two estimates this close are the same estimate. It happens honestly and often:
  # the market's curve is built from our own readings, so for the best player in a
  # position the two coincide exactly. Printing both would show the same figure
  # twice and read like a fault.
  AGREEMENT = 0.05

  # Near enough a full match that the distinction is not worth a sentence.
  FULL_MATCH = 89

  def initialize(working:, horizon:, position: nil, chance: nil)
    @working = (working || {}).symbolize_keys
    @horizon = horizon
    @position = position
    @chance = chance
  end

  def render?
    estimate.present?
  end

  private

  attr_reader :working, :horizon, :position, :chance

  def season?
    horizon == "season"
  end

  def goalkeeper?
    position == "goalkeeper"
  end

  # What the forecast does to this figure that these numbers do not show.
  #
  # Fitness and a goalkeeper's share of his club's one place are applied to the
  # finished answer and are not among the stored working, so without saying so
  # here the page contradicts itself: a man ruled out reads "worth 4.88 a game"
  # under a forecast of nought, and the reader is entitled to think one of them
  # is broken.
  def caveats
    [ fitness_caveat, keeper_caveat ].compact
  end

  def fitness_caveat
    return if chance.nil? || chance >= 100

    if chance.zero?
      "He is not expected to play at all this gameweek, which takes the forecast to nought whatever he is worth fit."
    else
      "He is rated #{chance}% likely to play, and the forecast is cut to match."
    end
  end

  def keeper_caveat
    return unless goalkeeper?

    "The forecast also allows for his share of his club's one goalkeeping place."
  end

  # What we think he is worth in a single game, before the horizon touches it.
  def estimate
    ours || crowd
  end

  def ours
    working[:ours]
  end

  def crowd
    working[:crowd]
  end

  def per_90
    working[:per_90]
  end

  def minutes
    working[:minutes]
  end

  # How far his record argues him away from what he costs, as a percentage. The
  # market leads and the record answers back, so this is the size of the reply.
  def record_swing
    swing(working[:perf_factor])
  end

  def form_swing
    swing(working[:form])
  end

  def transfer_swing
    swing(working[:transfers])
  end

  def swing(factor)
    return if factor.nil?
    return if (factor - 1).abs < NEGLIGIBLE

    factor
  end

  def games
    working[:games].to_f
  end

  # A single ordinary fixture multiplies by one, which is not news. The number is
  # only worth printing when the fixtures actually move it.
  def fixture_effect
    swing(games) unless season?
  end

  def single_fixture
    opponents.first if opponents.one?
  end

  def opponents
    Array(working[:opponents]).map(&:symbolize_keys)
  end

  def average_difficulty
    rated = opponents.filter_map { |opponent| opponent[:difficulty] }.reject(&:zero?)
    return if rated.empty?

    rated.sum / rated.size.to_f
  end

  # Both readings only where both exist. A player nobody owns has no market price
  # to be argued with, and one we cannot measure has no record to argue.
  def both_estimates?
    ours.present? && crowd.present?
  end

  # Worth showing side by side only when they actually differ.
  def estimates_differ?
    both_estimates? && (ours - crowd).abs >= AGREEMENT
  end

  def plays_full_match?
    minutes.to_i >= FULL_MATCH
  end

  # The rate only earns a line of its own when it is not simply the answer again.
  # A player who plays the full ninety is worth per 90 exactly what he is worth a
  # game, and saying so twice helps nobody.
  def rate_worth_stating?
    per_90.present? && (per_90 - estimate).abs >= AGREEMENT
  end

  def percentage(factor)
    format("%+d%%", ((factor - 1) * 100).round)
  end

  def points(value)
    format("%.2f", value)
  end
end
