module ComparisonsHelper
  # The answer in one word, for the top of the page and the middle of the card.
  #
  # Always a name where there is a forecast to name one from. A manager holding two
  # players and one transfer has to pick one of them, so declining to answer just
  # sends him away to guess. How close it was is said by the badge on the card.
  def verdict_name(head_to_head)
    head_to_head.pick&.player&.display_name || "No forecast"
  end

  # Why, in a sentence: the two numbers and the horizon they belong to.
  def verdict_line(head_to_head)
    return unforecast_line(head_to_head) unless head_to_head.forecast?

    "#{scores_line(head_to_head)} #{horizon_line(head_to_head)}"
  end

  # The one thing the cards cannot say for themselves: that there is no forecast
  # behind them, and so nothing to pick from.
  #
  # How close a pick was is not said here. The badge on the card already says it,
  # and the paragraph under the pair explains it; a third telling was a sentence
  # under two cards that had just made the same point.
  def comparison_note(head_to_head)
    unforecast_line(head_to_head) unless head_to_head.forecast?
  end

  def comparison_title(comparison)
    "#{comparison.left.short_name} or #{comparison.right.short_name}?"
  end

  def comparison_question(comparison)
    "#{comparison.left.full_name} or #{comparison.right.full_name}?"
  end

  # The big number on a card: what he is expected to score over the horizon being
  # read, as it stands.
  #
  # It used to be divided back down to a single week so that every horizon read on
  # the scale the grades are struck on. That answered a question nobody asks. A
  # manager looking at five gameweeks wants to know what five gameweeks are worth,
  # and one looking at the season wants the season. It also had the card quietly
  # disagreeing with the sentence beneath it, which has always quoted the total.
  #
  # The grade next to it is still read from the week, because a grade is a mark out
  # of ten and has to mean the same thing at every distance. See HeadToHead#weekly.
  # A tenth of a point separates two players over one gameweek and means nothing
  # over thirty-eight, so the decimal is dropped once the number is large enough
  # not to need it. It also keeps a season total clear of the photograph on the
  # share card, where the figure is set at 112 point.
  WHOLE_POINTS = 100

  def headline_points(side)
    return unless side.forecast?

    side.score >= WHOLE_POINTS ? side.score.round.to_s : format("%.1f", side.score)
  end

  # A side of a comparison in the terms the compact card asks for, so the pair are
  # drawn by the component the rankings are drawn by and cannot look like a
  # different site. The headline is the points, because a place in a position table
  # is not what these two are being weighed on.
  def comparison_card_arguments(head_to_head, side)
    {
      ranking: ConsensusRanking::Ranking.new(
        player_id: side.player.id, team_id: side.player.team_id, position: side.player.position,
        bot_rank: side.rank, score: side.score, tier: side.tier, grade: side.grade
      ),
      player: side.player,
      facts: { "now_cost" => side.cost, "selected_by_percent" => side.ownership },
      leading: headline_points(side) || "—"
    }
  end

  # A figure that favours a player is set in ink; the other is set quietly. Both
  # lit says less than neither.
  def comparison_value_class(leading)
    leading ? "font-bold text-zinc-950" : "text-zinc-500"
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
    "#{named}."
  end

  def horizon_line(head_to_head)
    "Expected points for #{Horizon.find(head_to_head.horizon).span}."
  end

  # A player we cannot forecast is not a player we rate at nought, and the page
  # should not imply that he is.
  def unforecast_line(head_to_head)
    missing = head_to_head.sides.reject(&:forecast?).map { |side| side.player.display_name }
    "No forecast for #{missing.to_sentence} this week, so there is nothing to compare."
  end
end
