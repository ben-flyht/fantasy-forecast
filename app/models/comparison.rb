# A count of how often a comparison has been asked for in a gameweek, kept against its
# canonical slug so the hub can offer the arguments people actually have — a fresh set
# each week.
#
# Matchup is the plain object that parses an address into its two sides; this is the
# record of one having been asked for. Every ask is counted, trades and pairs alike,
# but the hub surfaces pairs only, so each row records whether it is a pair and
# MostRequestedComparisons reads only those — the surfaced set is found without ever
# resolving a group slug, which a side of up to fifteen players makes deliberately
# expensive.
class Comparison < ApplicationRecord
  belongs_to :gameweek

  # create_or_find_by, not find_or_create_by: two people opening the same fresh
  # comparison at once both miss the find, and one of the creates loses the race on the
  # unique index. create_or_find_by expects that and re-finds rather than raising.
  def self.record(matchup, gameweek)
    create_or_find_by(gameweek: gameweek, slug: matchup.slug) { |row| row.pair = !matchup.group? }
      .increment!(:hits)
  end
end
