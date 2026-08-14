# A count of how often a comparison has been asked for, kept against its canonical
# slug so the hub can offer the arguments people actually have.
#
# Every request is counted, trades and pairs alike, because knowing a trade was asked
# is worth having. What the hub goes on to offer is a narrower thing — pairs only —
# and that choice lives in MostRequestedComparisons, not here.
class ComparisonRequest < ApplicationRecord
  def self.record(slug)
    find_or_create_by(slug: slug).increment!(:hits)
  end
end
