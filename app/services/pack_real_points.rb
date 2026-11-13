class PackRealPoints
  def initialize(gameweek)
    @scores = Performance.where(gameweek: gameweek).pluck(:player_id, :gameweek_score).to_h
  end

  def of(card) = @scores.fetch(card.player_id, 0)

  def for(hand) = hand.kept.sum { |card| of(card) } + (hand.captain ? of(hand.captain) : 0)

  def right_calls(hand)
    hand.picks.zip(hand.discards).count { |kept, others| %i[better level].include?(verdict(kept, others)) }
  end

  def verdict(kept, others)
    return :no_pick unless kept

    best_other = others.map { |other| of(other) }.max || 0
    { 1 => :better, 0 => :level, -1 => :worse }.fetch(of(kept) <=> best_other)
  end
end
