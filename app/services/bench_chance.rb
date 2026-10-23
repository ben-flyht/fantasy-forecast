module BenchChance
  MISS_RATE = 0.07

  module_function

  def at_least(count, of:)
    1 - (0...count).sum { |k| combinations(of, k) * MISS_RATE**k * (1 - MISS_RATE)**(of - k) }
  end

  def combinations(n, k) = (1..k).reduce(1) { |total, i| total * (n - i + 1) / i }
end
