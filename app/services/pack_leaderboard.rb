class PackLeaderboard
  Row = Data.define(:place, :selection, :points, :right, :pairs) do
    def user = selection.user
    def accuracy
      (right * 100).fdiv(pairs).round if right && pairs.positive?
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

  def unranked(selection) = Row.new(place: nil, selection: selection, points: nil, right: nil, pairs: 0)

  def ranked
    scored = selections.map { |selection| score(selection) }.sort_by { |row| [ -row.points, row.selection.created_at ] }
    scored.map { |row| row.with(place: scored.index { |other| other.points == row.points } + 1) }
  end

  def score(selection)
    hand = selection.pack_hand
    Row.new(place: nil, selection: selection, points: real.for(hand), right: real.right_calls(hand), pairs: hand.pack.size)
  end
end
