class AccuracyRating
  Z = 1.96

  def self.of(right, total) = new(right, total).score

  def initialize(right, total)
    @rate = right.fdiv(total)
    @total = total
  end

  def score = ((centre - spread) / shrink * 100).round

  private

  attr_reader :rate, :total

  def centre = rate + (Z**2 / (2 * total))

  def spread = Z * Math.sqrt((rate * (1 - rate) / total) + (Z**2 / (4 * total**2)))

  def shrink = 1 + (Z**2 / total)
end
