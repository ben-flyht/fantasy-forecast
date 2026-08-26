# frozen_string_literal: true

# A table of other players this money could be on.
#
# Used twice: once for the straight swap at about the same price, and once for
# what is available cheaper. Same table, same columns, different question at the
# top, because the reader is doing the same arithmetic either way.
class PlayerOptionsComponent < ViewComponent::Base
  def initialize(entries:, title:, subtitle:, horizon:, cost: nil, score: nil)
    @entries = entries
    @title = title
    @subtitle = subtitle
    @horizon = horizon
    @cost = cost
    @score = score
  end

  # A table whose only row is the player whose page it is has nothing to compare
  # him with, which is the one thing it exists to do.
  def render?
    entries.any? { |entry| !entry.subject? }
  end

  private

  attr_reader :entries, :title, :subtitle, :horizon, :cost, :score

  def points_label
    horizon == "season" ? "Rest of season" : "This week"
  end

  # Where he comes in the field being compared, said plainly. It is the answer to
  # the question the table was put there to ask, and it should not need counting
  # rows to find.
  def standing
    subject = entries.find(&:subject?)
    return if subject.nil? || subject.of.to_i < 2

    "He is #{subject.place.ordinalize} of #{subject.of}."
  end

  # How many places are missing immediately above this row.
  #
  # The shortlist is the best few and him, so a squad player arrives at his real
  # place in the order and the ranks in between are simply absent. That is the
  # right list to show, and shown without a word it read as a fault: the table
  # ran 1, 2, 3, 4, 5, 7 and left the reader to wonder where the sixth went.
  def skipped_before(entry, index)
    return 0 if index.zero?

    entry.place.to_i - entries[index - 1].place.to_i - 1
  end

  # What this player costs against the one whose page it is. Nothing is shown when
  # they cost the same, because "level" is not news.
  def difference(entry)
    return if entry.cost.nil? || cost.nil? || entry.cost == cost

    gap = entry.cost - cost
    "#{gap.negative? ? '-' : '+'}#{helpers.player_price(gap.abs)}"
  end

  # Forecast to do at least as well. The only ones that are genuinely an
  # alternative rather than a downgrade, so the page says which are which.
  def better?(entry)
    return false if score.nil? || entry.score.nil? || entry.subject?

    entry.score >= score
  end

  def points(entry)
    return "—" if entry.score.nil?

    format("%.1f", entry.score)
  end
end
