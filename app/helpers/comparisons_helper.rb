module ComparisonsHelper
  # The answer in one word, for the top of the page and the middle of the card.
  #
  # It is a name or it is nothing: saying "too close to call" is a real answer to
  # a manager deciding whether a transfer is worth a hit, and it is a good deal
  # more honest than separating two players by a twentieth of a point.
  def verdict_name(head_to_head)
    head_to_head.winner&.player&.display_name || "Too close to call"
  end

  # Why, in a sentence: the two numbers, and the horizon they belong to.
  def verdict_line(head_to_head)
    left, right = head_to_head.sides
    return unforecast_line(head_to_head) unless left.forecast? && right.forecast?

    "#{scores_line(head_to_head)} #{horizon_line(head_to_head)}"
  end

  def comparison_title(comparison)
    "#{comparison.left.short_name} or #{comparison.right.short_name}?"
  end

  def comparison_question(comparison)
    "#{comparison.left.full_name} or #{comparison.right.full_name}?"
  end

  # What a card is worth showing as a headline number: the week a score describes,
  # so both horizons read on the scale the grades use.
  def weekly_points(head_to_head, side)
    return unless side.forecast?

    format("%.1f", side.score / (head_to_head.season? ? Gameweek.remaining_count : 1))
  end

  def comparison_fixture(side)
    return "No fixture" unless side.match

    "#{side.home? ? 'v' : 'away to'} #{side.opponent&.short_name}"
  end

  private

  def scores_line(head_to_head)
    named = head_to_head.sides.sort_by { |side| -side.score }
                        .map { |side| "#{side.player.display_name} #{format('%.1f', side.score)}" }
                        .join(", ")
    head_to_head.tie? ? "Nothing in it: #{named}." : "#{named}."
  end

  def horizon_line(head_to_head)
    head_to_head.season? ? "Expected points for the rest of the season." : "Expected points this gameweek."
  end

  # A player we cannot forecast is not a player we rate at nought, and the page
  # should not imply that he is.
  def unforecast_line(head_to_head)
    missing = head_to_head.sides.reject(&:forecast?).map { |side| side.player.display_name }
    "No forecast for #{missing.to_sentence} this week, so there is nothing to compare."
  end
end
