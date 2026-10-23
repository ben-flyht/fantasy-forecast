class PackRealScore
  Result = Data.define(:points, :line_up, :substitutions, :final) do
    def final? = final
  end

  def initialize(gameweek)
    @gameweek = gameweek
  end

  def started? = gameweek.start_time.past?
  def final? = gameweek.is_finished

  def for(hand)
    line_up, substitutions = final? ? auto_substituted(hand) : [ hand.starters, [] ]
    captain = hand.captain if line_up.include?(hand.captain) && played?(hand.captain)

    Result.new(points: line_up.sum { |card| points_of(card) } + (captain ? points_of(captain) : 0),
               line_up: line_up, substitutions: substitutions, final: final?)
  end

  def points_of(card) = scores.fetch(card.player_id, 0)

  private

  attr_reader :gameweek

  def auto_substituted(hand)
    line_up = hand.starters.dup
    bench = hand.substitutes.select { |card| played?(card) }
    substitutions = hand.starters.reject { |card| played?(card) }.filter_map do |absent|
      incoming = replacement(line_up, absent, bench) or next
      line_up = line_up - [ absent ] + [ bench.delete(incoming) ]
      [ absent, incoming ]
    end

    [ line_up, substitutions ]
  end

  def replacement(line_up, absent, bench)
    bench.find { |card| PackHand.legal_line_up?(line_up - [ absent ] + [ card ]) }
  end

  def played?(card) = minutes.fetch(card.player_id, 0).positive?

  def scores
    @scores ||= Performance.where(gameweek: gameweek).pluck(:player_id, :gameweek_score).to_h
  end

  def minutes
    @minutes ||= Statistic.where(gameweek: gameweek, type: "minutes").pluck(:player_id, :value).to_h { |id, value| [ id, value.to_f ] }
  end
end
