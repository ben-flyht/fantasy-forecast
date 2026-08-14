# The arguments people are actually having this week, most-asked first.
#
# PopularComparisons offers the pairs our own forecast puts closest together, which is
# a good guess and never quite the question somebody arrived holding. This is the other
# half of that: the pairs managers have asked for themselves, read back off the tally
# every request leaves behind, and scoped to the gameweek so a new set surfaces each
# week rather than the same all-time list.
#
# Pairs only, though a group is counted the same as a pair. A hub of two-a-side groups
# would be a hub nobody can scan. Reading `pair: true` means no group slug is ever
# resolved here, so a crafted one cannot make the query expensive.
#
# When the week's tally is thin — early in a week, or a quiet one — it is topped up
# with the forecast's closest pairs, so the hub always offers something worth reading.
class MostRequestedComparisons < ApplicationService
  DEFAULT_LIMIT = 6

  def initialize(gameweek:, horizon: Horizon::GAMEWEEK, limit: DEFAULT_LIMIT)
    @gameweek = gameweek
    @horizon = horizon
    @limit = limit
  end

  def call
    return [] unless @gameweek

    asked = asked_pairs
    return asked if asked.size >= @limit

    (asked + close_pairs).uniq(&:slug).first(@limit)
  end

  private

  # More rows read than shown, so players since transferred out do not leave it short.
  def asked_pairs
    ComparisonRequest.where(gameweek: @gameweek, pair: true)
                     .order(hits: :desc, updated_at: :desc)
                     .limit(@limit * 4)
                     .filter_map { |request| pair_for(request.slug) }
                     .first(@limit)
  end

  # Highly ranked players our forecast can barely separate: exactly the picks somebody
  # is stuck on, and a good fallback for the ones nobody has asked yet.
  def close_pairs
    PopularComparisons.call(gameweek: @gameweek, horizon: @horizon).values.flatten
  end

  def pair_for(slug)
    comparison = Comparison.parse(slug)
    comparison if comparison.valid? && !comparison.group?
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
