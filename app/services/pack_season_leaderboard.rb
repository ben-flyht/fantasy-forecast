class PackSeasonLeaderboard
  Row = Data.define(:place, :user, :points, :right, :pairs, :weeks, :best, :real) do
    def accuracy
      (right * 100).fdiv(pairs).round if pairs.positive?
    end
  end

  def rows
    @rows ||= rank(totals)
  end

  private

  def totals
    weekly_rows.group_by { |row, _| row.user }.map do |user, entries|
      best, real = entries.max_by { |row, _| row.points }
      rows = entries.map(&:first)
      { user: user, points: best.points, right: rows.sum(&:right), pairs: rows.sum(&:pairs), weeks: rows.size, best: best, real: real }
    end
  end

  def weekly_rows
    Gameweek.started.ordered.flat_map do |gameweek|
      board = PackLeaderboard.new(gameweek)
      board.rows.map { |row| [ row, board.real ] }
    end
  end

  def rank(totals)
    sorted = totals.sort_by { |total| [ -total[:points], -total[:right], total[:user].leaderboard_name ] }
    sorted.map { |total| Row.new(place: sorted.index { |other| other[:points] == total[:points] } + 1, **total) }
  end
end
