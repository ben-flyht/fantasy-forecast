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
class MostRequestedComparisons < ApplicationService
  DEFAULT_LIMIT = 6
  LAST_WEEK_WEIGHT = 0.5

  def initialize(gameweek:, limit: DEFAULT_LIMIT)
    @gameweek = gameweek
    @limit = limit
  end

  def call
    return [] unless @gameweek

    asked_slugs.filter_map { |slug| pair_for(slug) }.first(@limit)
  end

  private

  # More rows read than shown, so players since transferred out do not leave it short.
  def asked_slugs
    Comparison.where(gameweek: tallied_weeks, pair: true)
              .group(:slug)
              .order(Arel.sql(weighted_hits), Arel.sql("MAX(updated_at) DESC"))
              .limit(@limit * 4)
              .pluck(:slug)
  end

  def weighted_hits
    Comparison.sanitize_sql_array(
      [ "SUM(CASE WHEN gameweek_id = ? THEN hits ELSE hits * ? END) DESC", @gameweek.id, LAST_WEEK_WEIGHT ]
    )
  end

  def tallied_weeks
    [ @gameweek, Gameweek.find_by(fpl_id: @gameweek.fpl_id - 1) ].compact
  end

  def pair_for(slug)
    comparison = Matchup.parse(slug)
    comparison if comparison.valid? && !comparison.group?
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
