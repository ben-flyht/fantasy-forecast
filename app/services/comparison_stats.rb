# The record underneath the answer: the numbers on a player that a manager most
# weighs a trade on, laid out so two sides can be read across.
#
# Not a forecast — the cards above are the forecast. This is what has actually
# happened: rates per 90, season totals and current form, each row labelled with
# what it is so a per-90 rate is never mistaken for a total.
#
# Where this season has not filled a figure in yet the record is last season's, and
# a row FPL kept only for this season simply waits until the season provides it. A
# side is worth what its players do between them, so the numbers are summed.
class ComparisonStats < ApplicationService
  # `this`/`last` are the stored figures for each season; `last` is nil where there is
  # no last-season equivalent. `better` says which way is good. `format` is how the
  # figure reads — a rate to two places, a total whole, an index to one.
  Stat = Struct.new(:this, :last, :term, :better, :format, :paid, keyword_init: true) do
    def order? = format == :order
  end

  Reading = Struct.new(:value, :text, keyword_init: true)

  Row = Struct.new(:term, :left, :right, :leader, keyword_init: true) do
    def label = term.label
  end

  Group = Struct.new(:title, :rows, keyword_init: true)

  # Read down in the order a manager weighs it: form and minutes first, then
  # attacking output, then defence, then bonus, then the discipline that only matters
  # when there is any. A row nobody has, that is nought on both sides, or that FPL
  # pays nobody on either side for, is not drawn.
  UNDERLYING = [
    Stat.new(this: "form", last: nil, term: :form, better: :high, format: :one),
    Stat.new(this: "season_points", last: "last_season_points", term: :points, better: :high, format: :whole),
    Stat.new(this: "season_minutes", last: "last_season_minutes", term: :minutes, better: :high, format: :whole),
    Stat.new(this: "season_starts", last: nil, term: :starts, better: :high, format: :whole),

    Stat.new(this: "season_goals", last: nil, term: :goals, better: :high, format: :whole),
    Stat.new(this: "season_assists", last: nil, term: :assists, better: :high, format: :whole),
    Stat.new(this: "expected_goals_per_90", last: "last_season_expected_goals_per_90",
             term: :expected_goals_per_90, better: :high, format: :two),
    Stat.new(this: "expected_assists_per_90", last: "last_season_expected_assists_per_90",
             term: :expected_assists_per_90, better: :high, format: :two),
    Stat.new(this: "penalties_order", last: "penalties_order", term: :penalties, better: :low, format: :order),

    Stat.new(this: "clean_sheets_per_90", last: "last_season_clean_sheets_per_90",
             term: :clean_sheets_per_90, better: :high, format: :two, paid: :sheets),
    Stat.new(this: "expected_goals_conceded_per_90", last: "last_season_expected_goals_conceded_per_90",
             term: :expected_goals_conceded_per_90, better: :low, format: :two, paid: :sheets),
    Stat.new(this: "saves_per_90", last: "last_season_saves_per_90",
             term: :saves_per_90, better: :high, format: :two, paid: :keeper),
    Stat.new(this: "defensive_contribution_per_90", last: "last_season_defensive_contribution_per_90",
             term: :defensive_contribution_per_90, better: :high, format: :two, paid: :defending),

    Stat.new(this: "season_bonus", last: "last_season_bonus", term: :bonus, better: :high, format: :whole),

    Stat.new(this: "season_yellow_cards", last: nil, term: :yellow_cards, better: :low, format: :whole),
    Stat.new(this: "season_red_cards", last: nil, term: :red_cards, better: :low, format: :whole)
  ].freeze

  def initialize(left:, right:)
    @left = Matchup::Side.wrap(left)
    @right = Matchup::Side.wrap(right)
  end

  def call
    rows = UNDERLYING.filter_map { |stat| row_for(stat) }
    return [] if rows.empty?

    [ Group.new(title: "Underlying numbers", rows: rows) ]
  end

  private

  attr_reader :left, :right

  def row_for(stat)
    key = season_started? ? stat.this : stat.last
    return if key.nil? || !paid_for?(stat)

    side_readings = sides.map { |side| reading_for(side, key, stat) }
    present = side_readings.filter_map(&:value)
    return if present.empty? || present.all?(&:zero?)

    row_of(stat, *side_readings)
  end

  def row_of(stat, left_reading, right_reading)
    Row.new(term: StatGlossary.fetch(stat.term), leader: leader(stat, left_reading.value, right_reading.value),
            left: left_reading.text, right: right_reading.text)
  end

  def sides = [ left, right ]

  def paid_for?(stat)
    sides.flat_map(&:players).any? { |player| ExpectedPoints.worth_showing?(stat.paid, player.position) }
  end

  def reading_for(side, key, stat)
    values = side.players.map { |player| readings.dig(player.id, key) }
    stat.order? ? duty_reading(values) : total_reading(values, stat.format)
  end

  # A side is worth what everybody on it does between them, so the figures are summed.
  # A total is only a total when we have all of it: a side missing one man's figure is
  # left blank rather than reported as the rest of the side without him.
  def total_reading(values, format)
    total = values.sum if values.all?
    Reading.new(value: total, text: display(total, format))
  end

  def duty_reading(values)
    best = values.compact.select { |order| order.between?(1, PlayerProfile::WORTH_MENTIONING) }.min
    Reading.new(value: best, text: best ? best.round.ordinalize : "—")
  end

  # Which side the figure favours, where it favours anybody. Equal is nobody: lighting
  # both sides of a row says less than lighting neither.
  def leader(stat, left_value, right_value)
    return duty_leader(left_value, right_value) if stat.order?
    return if stat.better.nil? || left_value.nil? || right_value.nil? || left_value == right_value

    higher = left_value > right_value
    higher == (stat.better == :high) ? :left : :right
  end

  def duty_leader(left_value, right_value)
    return if left_value == right_value
    return :left if right_value.nil?
    return :right if left_value.nil?

    left_value < right_value ? :left : :right
  end

  def display(value, style)
    return "—" if value.nil?

    case style
    when :whole then value.round.to_s
    when :one then format("%.1f", value)
    when :two then format("%.2f", value)
    end
  end

  def season_started?
    return @season_started unless @season_started.nil?

    @season_started = Gameweek.finished.any?
  end

  def readings
    @readings ||= Statistic.where(player_id: (left.players + right.players).map(&:id)).latest_by_player
  end
end
