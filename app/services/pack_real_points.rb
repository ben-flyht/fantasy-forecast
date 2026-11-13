class PackRealPoints
  CALLED = %i[better level worse no_pick].freeze

  def initialize(gameweek)
    @scores = Performance.where(gameweek: gameweek).pluck(:player_id, :gameweek_score).to_h
    @playing = Match.where(gameweek: gameweek, finished: false).pluck(:home_team_id, :away_team_id).flatten.to_set
  end

  def of(card) = @scores.fetch(card.player_id, 0)

  def for(hand) = hand.kept.sum { |card| of(card) } + (hand.captain ? of(hand.captain) : 0)

  def right_calls(hand) = verdicts(hand).count { |verdict| %i[better level].include?(verdict) }

  def called(hand) = verdicts(hand).count { |verdict| CALLED.include?(verdict) }

  def verdict(kept, others)
    return :no_pick unless kept
    return :pending unless [ kept, *others ].all? { |card| finished?(card) }

    best_other = others.map { |other| of(other) }.max || 0
    { 1 => :better, 0 => :level, -1 => :worse }.fetch(of(kept) <=> best_other)
  end

  private

  def finished?(card) = !@playing.include?(card.player.team_id)

  def verdicts(hand) = hand.picks.zip(hand.discards).map { |kept, others| verdict(kept, others) }
end
