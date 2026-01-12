# Assigns weather-themed tiers to player rankings based on their score
# relative to the top-ranked player (percentage from top score).
class TierCalculator
  TIERS = {
    1 => { symbol: "☀️", name: "Sunshine", description: "Must-start premium picks" },
    2 => { symbol: "🌤️", name: "Partly Cloudy", description: "Strong reliable options" },
    3 => { symbol: "☁️", name: "Cloudy", description: "Solid but higher variance" },
    4 => { symbol: "🌧️", name: "Rainy", description: "Risky, proceed with caution" },
    5 => { symbol: "❄️", name: "Snow", description: "Avoid - Loss/injury risks" }
  }.freeze

  # Percentage thresholds from top score (higher % = further from top)
  # Tier 1: Within 20% of top score
  # Tier 2: 20-40% below top score
  # Tier 3: 40-60% below top score
  # Tier 4: 60-80% below top score
  # Tier 5: More than 80% below top score (or unavailable)
  PERCENTAGE_THRESHOLDS = {
    t1: 20,
    t2: 40,
    t3: 60,
    t4: 80
  }.freeze

  def initialize(rankings, position: nil, top_score: nil)
    @rankings = rankings
    @position = position
    @top_score = top_score || find_top_score
  end

  def call
    return [] if @rankings.empty?

    @rankings.map { |ranking| assign_tier(ranking) }
  end

  def self.tier_info(tier_number)
    TIERS[tier_number]
  end

  private

  def find_top_score
    ranked = @rankings.select { |r| r.score.present? && r.score.positive? }
    ranked.map(&:score).max || 0
  end

  def assign_tier(ranking)
    tier = calculate_tier(ranking.score)
    tier_info = TIERS[tier]

    ranking.tier = tier
    ranking.tier_symbol = tier_info[:symbol]
    ranking.tier_name = tier_info[:name]
    ranking
  end

  def calculate_tier(score)
    return 5 if score.nil? || @top_score.zero?

    percentage_from_top = ((@top_score - score) / @top_score.to_f) * 100

    case percentage_from_top
    when -Float::INFINITY..PERCENTAGE_THRESHOLDS[:t1] then 1
    when PERCENTAGE_THRESHOLDS[:t1]..PERCENTAGE_THRESHOLDS[:t2] then 2
    when PERCENTAGE_THRESHOLDS[:t2]..PERCENTAGE_THRESHOLDS[:t3] then 3
    when PERCENTAGE_THRESHOLDS[:t3]..PERCENTAGE_THRESHOLDS[:t4] then 4
    else 5
    end
  end
end
