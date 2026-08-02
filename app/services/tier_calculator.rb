# Assigns weather-themed tiers to player rankings based on their score
# relative to the top-ranked player (percentage from top score).
class TierCalculator < ApplicationService
  TIERS = {
    1 => { symbol: "☀️", name: "Sunshine", description: "Must-start premium picks" },
    2 => { symbol: "🌤️", name: "Partly Cloudy", description: "Strong reliable options" },
    3 => { symbol: "☁️", name: "Cloudy", description: "Solid but higher variance" },
    4 => { symbol: "🌧️", name: "Rainy", description: "Risky, proceed with caution" },
    5 => { symbol: "❄️", name: "Snow", description: "Avoid - Loss/injury risks" }
  }.freeze

  # What each tier is worth, in expected points.
  #
  # Absolute rather than a share of whoever tops the position, because the number
  # means something now: four points is four points whether he keeps goal or plays
  # up front. Measuring against the position's best gave keepers ten sunshines and
  # midfielders one, purely because keepers all score alike and one striker runs
  # away with his position.
  #
  # Two points is turning up. The bands are what a player is expected to add on
  # top: a return of some kind for sunshine, down to nothing at all for snow.
  POINT_THRESHOLDS = { t1: 4.25, t2: 3.25, t3: 2.25, t4: 1.25 }.freeze

  # A whole-season score is dozens of points, not the two-to-four of one gameweek,
  # so it is averaged back over the gameweeks it spans before it meets the bands
  # above. A player who is Sunshine for a single week and a player who stays
  # Sunshine all season then read alike, which is the honest comparison.
  def initialize(rankings, position: nil, points_divisor: 1)
    @rankings = rankings
    @position = position
    @points_divisor = points_divisor
  end

  def call
    return [] if @rankings.empty?

    @rankings.map { |ranking| assign_tier(ranking) }
  end

  def self.tier_info(tier_number)
    TIERS[tier_number]
  end

  def self.tier_from_points(points)
    return 5 if points.nil?

    case points.to_f
    when POINT_THRESHOLDS[:t1].. then 1
    when POINT_THRESHOLDS[:t2]..POINT_THRESHOLDS[:t1] then 2
    when POINT_THRESHOLDS[:t3]..POINT_THRESHOLDS[:t2] then 3
    when POINT_THRESHOLDS[:t4]..POINT_THRESHOLDS[:t3] then 4
    else 5
    end
  end

  GRADE_LETTERS = { 1 => "A", 2 => "B", 3 => "C", 4 => "D", 5 => "F" }.freeze

  BAND_FLOORS = { 1 => 4.25, 2 => 3.25, 3 => 2.25, 4 => 1.25, 5 => 0.25 }.freeze

  def self.grade_from_points(points)
    return "-" if points.nil?

    tier = tier_from_points(points)
    return "-" if tier == 5

    "#{GRADE_LETTERS[tier]}#{grade_suffix(points.to_f - BAND_FLOORS[tier])}"
  end

  def self.grade_suffix(fraction)
    return "+" if fraction >= 0.6667
    return "-" if fraction < 0.3333

    ""
  end

  def self.calculate_player_tier(forecast, _position = nil)
    tier_info(tier_from_points(forecast.score))
  end

  private

  def assign_tier(ranking)
    points = per_gameweek(ranking.score)
    ranking.tier = self.class.tier_from_points(points)
    ranking.grade = self.class.grade_from_points(points)
    ranking
  end

  def per_gameweek(score)
    return score if score.nil? || @points_divisor <= 1

    score / @points_divisor
  end
end
