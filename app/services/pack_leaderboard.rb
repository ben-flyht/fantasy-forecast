class PackLeaderboard
  Row = Data.define(:place, :entry, :points) do
    def manager = entry.manager
  end

  def initialize(weekly_pack)
    @weekly_pack = weekly_pack
    @gameweek = weekly_pack.gameweek
  end

  def started? = gameweek.start_time.past?
  def final? = gameweek.is_finished

  def rows
    @rows ||= started? ? ranked : entries.sort_by(&:created_at).map { |entry| Row.new(place: nil, entry: entry, points: nil) }
  end

  def place_of(entry) = rows.find { |row| row.entry == entry }&.place

  private

  attr_reader :weekly_pack, :gameweek

  def entries
    @entries ||= weekly_pack.pack_entries.includes(:manager).to_a
  end

  def ranked
    scored = entries.map { |entry| [ entry, real.for(entry.pack_hand) ] }.sort_by { |entry, points| [ -points, entry.created_at ] }
    scored.map { |entry, points| Row.new(place: scored.index { |_, score| score == points } + 1, entry: entry, points: points) }
  end

  def real
    @real ||= PackRealPoints.new(gameweek)
  end
end
