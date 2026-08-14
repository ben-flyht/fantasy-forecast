# A count of how often a comparison has been asked for in a gameweek, kept against its
# canonical slug so the hub can offer the arguments people actually have — a fresh set
# each week.
#
# The table is `comparisons`; the model keeps the "request" in its name because
# `Comparison` is the plain object that parses an address, not a record. Every request
# is counted, trades and pairs alike, but the hub surfaces pairs only, so each row
# records whether it is a pair and MostRequestedComparisons reads only those — the
# surfaced set is found without ever resolving a group slug, which a side of up to
# fifteen players makes deliberately expensive.
class ComparisonRequest < ApplicationRecord
  self.table_name = "comparisons"

  belongs_to :gameweek

  # create_or_find_by, not find_or_create_by: two people opening the same fresh
  # comparison at once both miss the find, and one of the creates loses the race on the
  # unique index. create_or_find_by expects that and re-finds rather than raising.
  def self.record(comparison, gameweek)
    create_or_find_by(gameweek: gameweek, slug: comparison.slug) { |request| request.pair = !comparison.group? }
      .increment!(:hits)
  end
end
