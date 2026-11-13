class PackRealPoints
  Tally = Data.define(:got, :possible, :pairs) do
    def +(other) = with(got: got + other.got, possible: possible + other.possible, pairs: pairs + other.pairs)
  end
  NONE = Tally.new(got: 0, possible: 0, pairs: 0)

  def initialize(gameweek)
    @scores = Performance.where(gameweek: gameweek).pluck(:player_id, :gameweek_score).to_h
    @playing = Match.where(gameweek: gameweek, finished: false).pluck(:home_team_id, :away_team_id).flatten.to_set
  end

  def of(card) = @scores.fetch(card.player_id, 0)

  def for(hand) = hand.kept.sum { |card| of(card) } + (hand.captain ? of(hand.captain) : 0)

  def tally(hand)
    hand.pack.pairs.each_with_index.sum(NONE) { |pair, index| pair_tally(pair, hand.picks[index]) }
  end

  def verdict(kept, others)
    return :no_pick unless kept
    return :pending unless [ kept, *others ].all? { |card| finished?(card) }

    best_other = others.map { |other| of(other) }.max || 0
    { 1 => :better, 0 => :level, -1 => :worse }.fetch(of(kept) <=> best_other)
  end

  private

  def pair_tally(pair, kept)
    return NONE unless pair.cards.all? { |card| finished?(card) }

    weight = pair.shiny? ? 2 : 1
    Tally.new(got: (kept ? gain(kept) : 0) * weight, possible: pair.cards.map { |card| gain(card) }.max * weight, pairs: 1)
  end

  def gain(card) = [ of(card), 0 ].max

  def finished?(card) = !@playing.include?(card.player.team_id)
end
