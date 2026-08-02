# Marks a finished gameweek's forecast against what actually happened.
#
# Nothing is stored: forecasts and performances are both on disk, so any week can
# be re-marked at any time, including after the measure itself changes. That
# matters, because the first thing an accuracy number does is make you argue about
# the accuracy number.
#
# The headline is capture rate: of the points available from the best few players
# in a position, how many did ours get. It answers the question a reader actually
# has, "if I had taken your top picks, how would I have done", where a correlation
# answers a statistician's question instead.
#
# Baselines are the point. An accuracy figure on its own says nothing; the only
# useful question is whether we beat what you would have got for free:
#
#   fpl        - FPL's own expected points, published before the deadline
#   crowd      - who the most managers already own
#   last week  - whoever scored well in the previous gameweek
#   average    - the mean player, which is what picking blind gets you
class ForecastAccuracy < ApplicationService
  POSITIONS = %w[goalkeeper defender midfielder forward].freeze

  # How many players deep a reader realistically picks from.
  TOP = 10

  def initialize(gameweek:, top: TOP)
    @gameweek = gameweek
    @top = top
  end

  def call
    return false unless @gameweek&.is_finished?

    POSITIONS.index_with { |position| score_position(position) }.compact
  end

  private

  def score_position(position)
    players = player_ids_for(position)
    return nil if players.size <= @top

    best = ceiling(players)
    return nil if best.zero?

    marks(players, best)
  end

  def marks(players, best)
    {
      players: players.size,
      capture_rate: capture(ours(players), best),
      correlation: correlation(players, ours(players)),
      predicted: average(players.map { |id| forecasts[id].to_f }),
      actual: average(actuals_for(players)),
      baselines: baselines(players, best)
    }
  end

  def baselines(players, best)
    {
      fpl: capture(ordered_by(players, fpl_expected), best),
      crowd: capture(ordered_by(players, ownership), best),
      last_week: capture(ordered_by(players, previous_points), best),
      average: blind(players, best)
    }
  end

  # What picking at random gets you: the mean player, ten times over.
  def blind(players, best)
    (average(actuals_for(players)) * @top / best * 100).round(1)
  end

  # What our picks actually returned, as a share of the best that could have been
  # picked with hindsight.
  def capture(order, best)
    (order.first(@top).sum { |id| actual_points[id].to_f } / best * 100).round(1)
  end

  def ceiling(players)
    actuals_for(players).max(@top).sum
  end

  def actuals_for(players)
    players.map { |id| actual_points[id].to_f }
  end

  def ours(players)
    players.sort_by { |id| [ forecasts[id] ? 0 : 1, -forecasts[id].to_f ] }
  end

  def ordered_by(players, values)
    players.sort_by { |id| -values[id].to_f }
  end

  # Spearman: do we put them in the right order, whatever the magnitudes.
  def correlation(players, order)
    ours = ranks(order)
    theirs = ranks(players.sort_by { |id| -actual_points[id].to_f })
    pearson(players.map { |id| ours[id] }, players.map { |id| theirs[id] })
  end

  def ranks(order)
    order.each_with_index.to_h { |id, index| [ id, index + 1 ] }
  end

  def pearson(xs, ys)
    return nil if xs.size < 3

    dx = deviations(xs)
    dy = deviations(ys)
    spread = spread_of(dx, dy)
    return nil if spread.zero?

    (dx.zip(dy).sum { |a, b| a * b } / spread).round(3)
  end

  def spread_of(dx, dy)
    Math.sqrt(dx.sum { |d| d**2 } * dy.sum { |d| d**2 })
  end

  def deviations(values)
    mean = average(values)
    values.map { |value| value - mean }
  end

  def average(values)
    return 0.0 if values.empty?

    (values.sum / values.size.to_f).round(2)
  end

  def player_ids_for(position)
    forecasts.select { |id, _| positions[id] == position }.keys
  end

  # The week's own forecast, and only that one.
  #
  # A gameweek carries two forecasts per player: what he was expected to score
  # that week, and what he was expected to score across the rest of the season,
  # which is anchored to the same week. Reading both and building a hash from
  # them keeps whichever came back last, so a player we had put at 4.8 points was
  # marked as though we had said 172.5. It would not have failed. It would have
  # quietly returned a plausible number for the wrong forecast, which is the only
  # kind of bug an accuracy measure cannot survive.
  #
  # Marking a season total against one week's points is a fair question but a
  # different one, and it needs its own measure: a capture rate wants both sides
  # talking about the same football.
  def forecasts
    @forecasts ||= Forecast.weekly.where(gameweek: @gameweek).pluck(:player_id, :score).to_h
  end

  def positions
    @positions ||= Player.where(id: forecasts.keys).pluck(:id, :position).to_h
  end

  # A player with no performance did not play, which is nought points, not a gap.
  def actual_points
    @actual_points ||= Hash.new(0).merge(
      Performance.where(gameweek: @gameweek).pluck(:player_id, :gameweek_score).to_h
    )
  end

  def previous_points
    @previous_points ||= begin
      previous = Gameweek.where("fpl_id < ?", @gameweek.fpl_id).order(:fpl_id).last
      previous ? Hash.new(0).merge(Performance.where(gameweek: previous).pluck(:player_id, :gameweek_score).to_h) : Hash.new(0)
    end
  end

  def fpl_expected
    @fpl_expected ||= snapshot("ep_next")
  end

  def ownership
    @ownership ||= snapshot("selected_by_percent")
  end

  # Read as it stood when the forecast was made, not as it stands now.
  def snapshot(type)
    Hash.new(0).merge(
      Statistic.where(gameweek: @gameweek, type: type).pluck(:player_id, :value).to_h
    )
  end
end
