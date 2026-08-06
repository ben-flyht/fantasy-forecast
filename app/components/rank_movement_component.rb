# frozen_string_literal: true

# Which way a player is heading, read under the rank it belongs to.
#
# A rank on its own says where he stands; only a run of them says whether he is
# on his way up. Nothing renders until there are two weeks to compare, which
# means this stays invisible until the season has been going a fortnight.
class RankMovementComponent < ViewComponent::Base
  def initialize(history:)
    @history = history
  end

  def render?
    history.ranks.many?
  end

  private

  attr_reader :history

  def change
    history.rank_change
  end

  def climbing?
    change.to_i.positive?
  end

  def steady?
    change.to_i.zero?
  end

  # Said in places rather than in signs, because "-8" reads as bad news and a rank
  # falling by eight is the opposite.
  def movement
    return "No change" if steady?

    "#{climbing? ? '▲' : '▼'} #{pluralize(change.abs, 'place')}"
  end

  def movement_class
    return "text-zinc-500" if steady?

    climbing? ? "text-green-700" : "text-red-700"
  end
end
