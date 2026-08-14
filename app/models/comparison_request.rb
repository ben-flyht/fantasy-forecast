# A count of how often a comparison has been asked for, kept against its canonical
# slug so the hub can offer the arguments people actually have.
#
# Every request is counted, trades and pairs alike, because knowing a trade was asked
# is worth having. What the hub goes on to offer is a narrower thing — pairs only —
# so each row records whether it is a pair, and MostRequestedComparisons reads only
# those. That way the surfaced set is found without ever resolving a group slug, which
# a side of up to fifteen players makes deliberately more expensive to look up.
class ComparisonRequest < ApplicationRecord
  # create_or_find_by, not find_or_create_by: two people opening the same fresh
  # comparison at once both miss the find, and one of the creates loses the race on the
  # unique index. create_or_find_by expects that and re-finds rather than raising.
  def self.record(comparison)
    create_or_find_by(slug: comparison.slug) { |request| request.pair = !comparison.group? }
      .increment!(:hits)
  end
end
