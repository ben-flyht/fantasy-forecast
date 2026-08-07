# The fifteen players the budget buys, and which eleven of them start.
#
# `picks` holds the search's answer verbatim: player id, position, cost and expected
# points at the moment it was picked. Written down rather than joined at read time,
# because a price rise a week later should not quietly rewrite what we recommended.
class Squad < ApplicationRecord
  belongs_to :gameweek

  HORIZONS = %w[gameweek season].freeze
  SEASON = "season".freeze
  GOALKEEPER = "goalkeeper".freeze

  validates :horizon, inclusion: { in: HORIZONS }
  validates :formation, presence: true

  scope :for_horizon, ->(horizon) { where(horizon: horizon) }

  def starters = picks.select { |pick| pick["starting"] }
  def substitutes = picks.reject { |pick| pick["starting"] }

  # The bench as FPL itself lists it: the reserve keeper first, then the three
  # outfield in the order they would come on.
  def bench
    keeper, outfield = substitutes.partition { |pick| pick["position"] == GOALKEEPER }
    keeper + outfield.sort_by { |pick| -pick["expected_points"].to_f }
  end

  # A pick as the rankings would describe him, so the rankings' own row can draw him
  # and the two pages cannot drift apart.
  #
  # A season score spans many gameweeks, so it is averaged back to one before it
  # meets the grade bands: a season grade then means what a weekly grade means.
  def ranking_for(pick)
    weekly = pick["expected_points"].to_f / points_divisor

    ConsensusRanking::Ranking.new(
      player_id: pick["player_id"], team_id: pick["team_id"], position: pick["position"],
      score: pick["expected_points"], tier: TierCalculator.tier_from_points(weekly),
      grade: TierCalculator.grade_from_points(weekly)
    )
  end

  def starters_in(position)
    starters.select { |pick| pick["position"] == position }
            .sort_by { |pick| -pick["expected_points"].to_f }
  end

  def captain = starters.max_by { |pick| pick["expected_points"].to_f }

  def player_ids = picks.map { |pick| pick["player_id"] }

  def spent_on_starters = starters.sum { |pick| pick["cost"].to_i }
  def banked = SquadOptimiser::BUDGET - cost

  def season? = horizon == SEASON

  private

  def points_divisor = season? ? Gameweek.remaining_count : 1
end
