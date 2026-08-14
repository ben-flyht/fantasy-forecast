module ComparisonsHelper
  # The answer in one word, for the top of the page and the middle of the card.
  #
  # Always a name where there is a forecast to name one from. A manager holding two
  # players and one transfer has to pick one of them, so declining to answer just
  # sends him away to guess. How close it was is said by the badge on the card.
  def verdict_name(head_to_head)
    side = head_to_head.pick
    side ? side_name(side) : "No forecast"
  end

  # A side said in as few words as will do: his name, or the names on it.
  def side_name(side)
    and_list(side.players.map(&:display_name))
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
    question(comparison) { |side| and_list(side.players.map(&:short_name)) }
  end

  def comparison_question(comparison)
    question(comparison) { |side| and_list(side.players.map(&:full_name)) }
  end

  # The cross for taking a player off a side, in a tone of his own club's colour so it
  # belongs to the card rather than sitting on it as a foreign white dot. The colour is
  # pushed further the way its own ink already runs — darker on a dark shirt, paler on a
  # pale one — so the ink stays readable on it.
  def remove_button_style(team)
    toward = team&.on_light? ? "#ffffff" : "#000000"
    "background-color: color-mix(in srgb, #{card_colour(team)} 72%, #{toward}); color: #{card_ink(team)};"
  end

  # Three players score more than two. Where the sides are not the same size the page
  # says so, rather than letting the bigger one win on nothing but being bigger.
  def uneven_note(head_to_head)
    return if head_to_head.level?

    "One side holds more players than the other, so it is expected to score more for " \
      "that reason alone. This is not a like-for-like question."
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
  def headline_points(side)
    return unless side.forecast?

    card_points(side.score)
  end

  # One player of a comparison in the terms the compact card asks for, so the sides are
  # drawn by the component the rankings are drawn by and cannot look like a different
  # site. The headline is the points, because a place in a position table is not what
  # these players are being weighed on.
  def comparison_card_arguments(member)
    {
      ranking: ConsensusRanking::Ranking.new(
        player_id: member.player.id, team_id: member.player.team_id, position: member.player.position,
        bot_rank: member.rank, score: member.score, tier: member.tier, grade: member.grade
      ),
      player: member.player,
      facts: { "now_cost" => member.cost, "selected_by_percent" => member.ownership },
      leading: headline_points(member) || "—"
    }
  end

  # A figure that favours a player is set in ink; the other is set quietly. Both
  # lit says less than neither.
  def comparison_value_class(leading)
    leading ? "font-bold text-zinc-950" : "text-zinc-500"
  end

  private

  # "Him or him?", and where a side holds more than one, "these two, or those two?".
  # The comma is what stops four names reading as one list of four.
  def question(comparison)
    names = comparison.sides.map { |side| yield(side) }
    "#{names.join(comparison.group? ? ', or ' : ' or ')}?"
  end

  # Names as somebody would say them, which is not how to_sentence says them.
  def and_list(names)
    return names.first if names.one?

    "#{names[0..-2].join(', ')} and #{names.last}"
  end

  def scores_line(head_to_head)
    named = head_to_head.sides.sort_by { |side| -side.score }
                        .map { |side| "#{side_name(side)} #{format('%.1f', side.score)}" }
                        .join(", ")
    "#{named}."
  end

  def horizon_line(head_to_head)
    "Expected points for #{Horizon.find(head_to_head.horizon).span}."
  end

  # A player we cannot forecast is not a player we rate at nought, and the page
  # should not imply that he is.
  def unforecast_line(head_to_head)
    missing = head_to_head.sides.flat_map(&:members).reject(&:forecast?)
                          .map { |member| member.player.display_name }
    "No forecast for #{missing.to_sentence} this week, so there is nothing to compare."
  end
end
