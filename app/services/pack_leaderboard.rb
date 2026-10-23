class PackLeaderboard
  Row = Data.define(:name, :manager_id, :captain, :expected_points, :real_points, :accuracy, :forecast) do
    def forecast? = forecast
  end

  def initialize(weekly)
    @weekly = weekly
    @real = PackRealScore.new(weekly.gameweek)
  end

  def started? = real.started?
  def final? = real.final?

  def rows
    @rows ||= (entries + [ forecast_row ]).sort_by { |row| [ -(row.real_points || 0), -row.expected_points ] }
  end

  def entry_count = weekly.pack_entries.size

  private

  attr_reader :weekly, :real

  def accuracy
    @accuracy ||= PackAccuracy.new(weekly.pack, real)
  end

  def entries
    weekly.pack_entries.includes(:manager).map do |entry|
      row_for(entry.manager.nickname, entry.pack_hand, entry.expected_points, manager_id: entry.manager_id)
    end
  end

  def forecast_row
    score = PackScore.new(weekly.pack)
    row_for("The forecast", score.forecast, score.points(score.forecast), forecast: true)
  end

  def row_for(name, hand, expected_points, manager_id: nil, forecast: false)
    Row.new(name: name, manager_id: manager_id, captain: hand.captain, expected_points: expected_points,
            real_points: (real.for(hand).points if started?), accuracy: (accuracy.of(hand) if final?), forecast: forecast)
  end
end
