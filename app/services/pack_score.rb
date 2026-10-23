class PackScore
  def initialize(pack)
    @pack = pack
  end

  def forecast
    @forecast ||= PackHand.new(pack, keeps: pack.pairs.map { |pair| pair.cards.index(pair.cards.max_by(&:expected_points)) })
  end

  def agreements(hand) = hand.kept.zip(forecast.kept).count { |mine, theirs| mine == theirs }

  private

  attr_reader :pack
end
