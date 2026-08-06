# The fifteen players the budget buys, and which eleven of them start.
#
# `picks` holds the search's answer verbatim: player id, position, cost and expected
# points at the moment it was picked. Written down rather than joined at read time,
# because a price rise a week later should not quietly rewrite what we recommended.
class Squad < ApplicationRecord
  belongs_to :gameweek

  HORIZONS = %w[gameweek season].freeze

  validates :horizon, inclusion: { in: HORIZONS }
  validates :formation, presence: true

  scope :for_horizon, ->(horizon) { where(horizon: horizon) }

  def starters = picks.select { |pick| pick["starting"] }
  def substitutes = picks.reject { |pick| pick["starting"] }

  # Bench order is the order they would come on, and the reserve keeper comes on for
  # nobody but our own keeper, so he sits at the end however good he is.
  def bench
    outfield, keeper = substitutes.partition { |pick| pick["position"] != "goalkeeper" }
    outfield.sort_by { |pick| -pick["expected_points"].to_f } + keeper
  end

  def starters_in(position)
    starters.select { |pick| pick["position"] == position }
            .sort_by { |pick| -pick["expected_points"].to_f }
  end

  def captain = starters.max_by { |pick| pick["expected_points"].to_f }

  def player_ids = picks.map { |pick| pick["player_id"] }

  def spent_on_starters = starters.sum { |pick| pick["cost"].to_i }
  def banked = SquadOptimiser::BUDGET - cost
end
