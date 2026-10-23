class PackScore
  OUTFIELD_STARTERS = 4
  BENCH_WEIGHTS = [
    BenchChance.at_least(1, of: OUTFIELD_STARTERS),
    BenchChance.at_least(2, of: OUTFIELD_STARTERS)
  ].freeze

  def initialize(pack)
    @pack = pack
  end

  def points(hand)
    hand.starters.sum(&:expected_points) +
      hand.captain&.expected_points.to_f +
      hand.substitutes.each_with_index.sum { |card, place| card.expected_points * BENCH_WEIGHTS[place] }
  end

  def perfect
    @perfect ||= PackHand.every_line_up(pack).max_by { |hand| points(hand) }
  end

  def forecast
    @forecast ||= best_line_up(pack.pairs.map { |pair| pair.cards.each_index.max_by { |index| pair.cards[index].expected_points } })
  end

  def share(hand)
    best = points(perfect)
    best.positive? ? points(hand) / best : 0.0
  end

  private

  attr_reader :pack

  def best_line_up(keeps)
    PackHand.new(pack, keeps: keeps).line_ups.max_by { |hand| points(hand) }
  end
end
