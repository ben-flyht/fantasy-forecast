class PackSeasonLeaderboard
  PRIOR_POINTS = 60
  PRO_RATING = 85

  Row = Data.define(:place, :user, :points, :got, :possible, :pairs, :weeks, :best, :real, :average) do
    def accuracy
      (got * 100).fdiv(possible).round(1) if possible.positive?
    end

    def score = (got + (PRIOR_POINTS * average)).fdiv(possible + PRIOR_POINTS) * 100

    def rating = score.round(1)

    def pro? = rating >= PRO_RATING
  end

  def rows
    @rows ||= rank(totals) { |row| row.points }
  end

  def pros = totals.select(&:pro?).map(&:user)

  def accuracy_rows
    @accuracy_rows ||= rank(totals) { |row| row.rating }
  end

  private

  def totals
    @totals ||= begin
      rows = weekly_rows.group_by { |row, _| row.user }.map { |user, entries| total(user, entries) }
      average = field_average(rows)
      rows.map { |row| row.with(average: average) }
    end
  end

  def field_average(rows)
    possible = rows.sum(&:possible)
    possible.positive? ? rows.sum(&:got).fdiv(possible) : 0.5
  end

  def total(user, entries)
    best, real = entries.max_by { |row, _| row.points }
    rows = entries.map(&:first)
    Row.new(place: nil, user: user, points: best.points, got: rows.sum(&:got), possible: rows.sum(&:possible),
            pairs: rows.sum(&:pairs), weeks: rows.size, best: best, real: real, average: 0.5)
  end

  def weekly_rows
    Gameweek.started.ordered.flat_map do |gameweek|
      board = PackLeaderboard.new(gameweek)
      board.rows.map { |row| [ row, board.real ] }
    end
  end

  def rank(rows, &score)
    sorted = rows.sort_by { |row| [ -score.call(row), -row.possible, row.user.leaderboard_name ] }
    sorted.map { |row| row.with(place: sorted.index { |other| score.call(other) == score.call(row) } + 1) }
  end
end
