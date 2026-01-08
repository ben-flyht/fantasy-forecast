# Assigns weather-themed tiers to player rankings based on their rank position.
# Uses position-aware tier boundaries to account for different pool sizes.
class TierCalculator
  TIERS = {
    1 => { symbol: "☀️", name: "Sunshine", description: "Must-start premium picks" },
    2 => { symbol: "🌤️", name: "Partly Cloudy", description: "Strong reliable options" },
    3 => { symbol: "☁️", name: "Cloudy", description: "Solid but higher variance" },
    4 => { symbol: "🌧️", name: "Rainy", description: "Risky, proceed with caution" },
    5 => { symbol: "❄️", name: "Snow", description: "Avoid - Loss/injury risks" }
  }.freeze

  # Position-aware tier boundaries (max rank for each tier)
  TIER_BOUNDARIES = {
    "goalkeeper" => { t1: 2, t2: 5, t3: 10, t4: 15 },
    "defender"   => { t1: 5, t2: 12, t3: 25, t4: 40 },
    "midfielder" => { t1: 5, t2: 12, t3: 25, t4: 40 },
    "forward"    => { t1: 3, t2: 8, t3: 15, t4: 25 }
  }.freeze

  DEFAULT_BOUNDARIES = { t1: 5, t2: 12, t3: 25, t4: 40 }.freeze

  def initialize(rankings, position:)
    @rankings = rankings
    @position = position
    @boundaries = TIER_BOUNDARIES[position] || DEFAULT_BOUNDARIES
  end

  def call
    return [] if @rankings.empty?

    @rankings.map { |ranking| assign_tier(ranking) }
  end

  def self.tier_info(tier_number)
    TIERS[tier_number]
  end

  private

  def assign_tier(ranking)
    tier = calculate_tier(ranking.bot_rank)
    tier_info = TIERS[tier]

    ranking.tier = tier
    ranking.tier_symbol = tier_info[:symbol]
    ranking.tier_name = tier_info[:name]
    ranking
  end

  def calculate_tier(rank)
    return 5 if rank.nil? # Unranked players (unavailable) go to Snow tier

    case rank
    when 1..@boundaries[:t1] then 1
    when (@boundaries[:t1] + 1)..@boundaries[:t2] then 2
    when (@boundaries[:t2] + 1)..@boundaries[:t3] then 3
    when (@boundaries[:t3] + 1)..@boundaries[:t4] then 4
    else 5
    end
  end
end
