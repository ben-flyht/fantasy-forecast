class PackRealPoints
  def initialize(gameweek)
    @scores = Performance.where(gameweek: gameweek).pluck(:player_id, :gameweek_score).to_h
  end

  def of(card) = @scores.fetch(card.player_id, 0)

  def for(hand) = hand.kept.sum { |card| of(card) } + (hand.captain ? of(hand.captain) : 0)
end
