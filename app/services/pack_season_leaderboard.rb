class PackSeasonLeaderboard
  Row = Data.define(:place, :user, :points, :right, :pairs, :weeks, :best, :real) do
    def accuracy
      (right * 100).fdiv(pairs).round if pairs.positive?
    end

    def rating
      pairs.positive? ? AccuracyRating.of(right, pairs) : 0
    end
  end

  def rows
    @rows ||= rank(totals) { |row| row.points }
  end

  def accuracy_rows
    @accuracy_rows ||= rank(totals) { |row| row.rating }
  end

  private

  def totals
    @totals ||= weekly_rows.group_by { |row, _| row.user }.map do |user, entries|
      best, real = entries.max_by { |row, _| row.points }
      rows = entries.map(&:first)
      Row.new(place: nil, user: user, points: best.points, right: rows.sum(&:right), pairs: rows.sum(&:pairs), weeks: rows.size, best: best, real: real)
    end
  end

  def weekly_rows
    Gameweek.started.ordered.flat_map do |gameweek|
      board = PackLeaderboard.new(gameweek)
      board.rows.map { |row| [ row, board.real ] }
    end
  end

  def rank(rows, &score)
    sorted = rows.sort_by { |row| [ -score.call(row), -row.pairs, row.user.leaderboard_name ] }
    sorted.map { |row| row.with(place: sorted.index { |other| score.call(other) == score.call(row) } + 1) }
  end
end
