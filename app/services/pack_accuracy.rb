class PackAccuracy
  def initialize(pack, real)
    @pack = pack
    @real = real
  end

  def of(hand)
    best.positive? ? real.for(hand).points.to_f / best : 0.0
  end

  def best
    @best ||= PackHand.every_line_up(pack).map { |hand| real.for(hand).points }.max.to_i
  end

  private

  attr_reader :pack, :real
end
