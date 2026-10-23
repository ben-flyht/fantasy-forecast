class PackScore
  def initialize(pack)
    @pack = pack
  end

  def points(hand) = hand.kept.sum(&:expected_points) + hand.captain&.expected_points.to_f

  def perfect
    @perfect ||= PackHand.every(pack).max_by { |hand| points(hand) }
  end

  def forecast
    @forecast ||= PackHand.new(pack, keeps: pack.pairs.map { |pair| pair.cards.index(pair.cards.max_by(&:expected_points)) })
  end

  def share(hand)
    best = points(perfect)
    best.positive? ? points(hand) / best : 0.0
  end

  private

  attr_reader :pack
end
