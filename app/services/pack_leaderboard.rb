class PackLeaderboard
  Row = Data.define(:place, :selection, :points, :got, :possible, :pairs) do
    def user = selection.user

    def accuracy
      (got * 100).fdiv(possible).round if possible.to_i.positive?
    end
  end

  def initialize(gameweek)
    @gameweek = gameweek
  end

  def rows
    @rows ||= gameweek.started? ? ranked : selections.sort_by(&:created_at).map { |selection| unranked(selection) }
  end

  def row_for(selection) = rows.find { |row| row.selection == selection }

  def real
    @real ||= PackRealPoints.new(gameweek)
  end

  private

  attr_reader :gameweek

  def selections
    @selections ||= Selection.where(gameweek: gameweek).includes(:user, :gameweek).to_a
  end

  def unranked(selection) = Row.new(place: nil, selection: selection, points: nil, got: 0, possible: 0, pairs: 0)

  def ranked
    scored = selections.map { |selection| score(selection) }.sort_by { |row| [ -row.points, row.selection.created_at ] }
    scored.map { |row| row.with(place: scored.index { |other| other.points == row.points } + 1) }
  end

  def score(selection)
    hand = selection.pack_hand
    Row.new(place: nil, selection: selection, points: real.for(hand), **real.tally(hand).to_h)
  end
end
