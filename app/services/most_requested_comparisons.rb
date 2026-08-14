# The arguments people are actually having, most-asked first.
#
# PopularComparisons offers the pairs our own forecast puts closest together, which
# is a good guess and never quite the question somebody arrived holding. This is the
# other half of that: the pairs managers have asked for themselves, read back off the
# tally every request leaves behind.
#
# Pairs only, though a group is counted the same as a pair. A hub of two-a-side groups
# would be a hub nobody can scan, and the whole point of it is a page a reader can
# scan. A manager builds the group he has in mind; the hub offers the straight choices.
class MostRequestedComparisons < ApplicationService
  DEFAULT_LIMIT = 6

  def initialize(limit: DEFAULT_LIMIT)
    @limit = limit
  end

  # More rows are read than are shown, so groups and players since transferred out do
  # not leave the list short.
  def call
    ComparisonRequest.order(hits: :desc, updated_at: :desc)
                     .limit(@limit * 4)
                     .filter_map { |request| pair_for(request.slug) }
                     .first(@limit)
  end

  private

  def pair_for(slug)
    comparison = Comparison.parse(slug)
    comparison if comparison.valid? && !comparison.group?
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
