class PackLeaderboard
  Row = Data.define(:place, :selection, :points) do
    def user = selection.user
  end

  def initialize(gameweek)
    @gameweek = gameweek
  end

  def started? = gameweek.start_time.past?
  def final? = gameweek.is_finished

  def rows
    @rows ||= started? ? ranked : selections.sort_by(&:created_at).map { |selection| Row.new(place: nil, selection: selection, points: nil) }
  end

  def row_for(selection) = rows.find { |row| row.selection == selection }

  private

  attr_reader :gameweek

  def selections
    @selections ||= Selection.where(gameweek: gameweek).includes(:user, :gameweek).to_a
  end

  def ranked
    scored = selections.map { |selection| [ selection, real.for(selection.pack_hand) ] }
                       .sort_by { |selection, points| [ -points, selection.created_at ] }
    scored.map { |selection, points| Row.new(place: scored.index { |_, score| score == points } + 1, selection: selection, points: points) }
  end

  def real
    @real ||= PackRealPoints.new(gameweek)
  end
end
