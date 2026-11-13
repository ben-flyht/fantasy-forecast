class PackSeasonLeaderboard
  Row = Data.define(:place, :user, :points, :right, :pairs, :weeks) do
    def accuracy
      (right * 100).fdiv(pairs).round if pairs.positive?
    end
  end

  def rows
    @rows ||= rank(totals)
  end

  private

  def totals
    weekly_rows.group_by(&:user).map do |user, rows|
      { user: user, points: rows.sum(&:points), right: rows.sum(&:right), pairs: rows.sum(&:pairs), weeks: rows.size }
    end
  end

  def weekly_rows
    Gameweek.started.ordered.flat_map { |gameweek| PackLeaderboard.new(gameweek).rows }
  end

  def rank(totals)
    sorted = totals.sort_by { |total| [ -total[:points], -total[:right], total[:user].leaderboard_name ] }
    sorted.map { |total| Row.new(place: sorted.index { |other| other[:points] == total[:points] } + 1, **total) }
  end
end
