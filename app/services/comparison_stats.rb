# The record underneath the answer: everything we hold on a player that a manager
# weighs a trade on, laid out so two sides can be read across.
#
# Not a forecast — the cards above are the forecast. This is what has actually
# happened: rates per 90, season totals, current form, and FPL's own indices, each
# row labelled with what it is so a per-90 rate is never mistaken for a total.
#
# Where this season has not filled a figure in yet the record is last season's, and
# a row FPL kept only for this season simply waits until the season provides it. A
# side is worth what its players do between them, so the numbers are summed.
class ComparisonStats < ApplicationService
  # `this`/`last` are the stored figures for each season; `last` is nil where there is
  # no last-season equivalent. `better` says which way is good. `format` is how the
  # figure reads — a rate to two places, a total whole, an index to one.
  Stat = Struct.new(:this, :last, :label, :better, :format, keyword_init: true)

  Reading = Struct.new(:value, :text, keyword_init: true)

  Row = Struct.new(:label, :left, :right, :leader, keyword_init: true)

  Group = Struct.new(:title, :rows, keyword_init: true)

  UNDERLYING = [
    Stat.new(this: "form", last: nil, label: "Form", better: :high, format: :one),
    Stat.new(this: "season_points", last: "last_season_points", label: "Points", better: :high, format: :whole),
    Stat.new(this: "season_minutes", last: "last_season_minutes", label: "Minutes", better: :high, format: :whole),
    Stat.new(this: "starts_per_90", last: nil, label: "Starts, per 90", better: :high, format: :two),
    Stat.new(this: "season_goals", last: nil, label: "Goals", better: :high, format: :whole),
    Stat.new(this: "season_assists", last: nil, label: "Assists", better: :high, format: :whole),
    Stat.new(this: "expected_goals_per_90", last: "last_season_expected_goals_per_90",
             label: "Expected goals, per 90", better: :high, format: :two),
    Stat.new(this: "expected_goal_involvements_per_90", last: "last_season_expected_goal_involvements_per_90",
             label: "Expected goals and assists, per 90", better: :high, format: :two),
    Stat.new(this: "expected_goals_conceded_per_90", last: nil,
             label: "Expected goals conceded, per 90", better: :low, format: :two),
    Stat.new(this: "clean_sheets_per_90", last: "last_season_clean_sheets_per_90",
             label: "Clean sheets, per 90", better: :high, format: :two),
    Stat.new(this: "saves_per_90", last: "last_season_saves_per_90",
             label: "Saves, per 90", better: :high, format: :two),
    Stat.new(this: "defensive_contribution_per_90", last: nil,
             label: "Defensive contributions, per 90", better: :high, format: :two),
    Stat.new(this: "season_bonus", last: "last_season_bonus", label: "Bonus points", better: :high, format: :whole),
    Stat.new(this: "bps", last: nil, label: "Bonus points system (BPS)", better: :high, format: :whole),
    Stat.new(this: "ict_index", last: nil, label: "ICT index", better: :high, format: :one),
    Stat.new(this: "threat", last: nil, label: "Threat", better: :high, format: :one),
    Stat.new(this: "creativity", last: nil, label: "Creativity", better: :high, format: :one),
    Stat.new(this: "influence", last: nil, label: "Influence", better: :high, format: :one)
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
    return if key.nil?

    side_readings = sides.map { |side| reading_for(side, key, stat.format) }
    present = side_readings.filter_map(&:value)
    return if present.empty? || present.all?(&:zero?)

    row_of(stat, *side_readings)
  end

  def row_of(stat, left_reading, right_reading)
    Row.new(label: stat.label, leader: leader(stat, left_reading.value, right_reading.value),
            left: left_reading.text, right: right_reading.text)
  end

  def sides = [ left, right ]

  # A side is worth what everybody on it does between them, so the figures are summed.
  # A total is only a total when we have all of it: a side missing one man's figure is
  # left blank rather than reported as the rest of the side without him.
  def reading_for(side, key, format)
    values = side.players.map { |player| readings.dig(player.id, key) }
    total = values.sum if values.all?
    Reading.new(value: total, text: display(total, format))
  end

  # Which side the figure favours, where it favours anybody. Equal is nobody: lighting
  # both sides of a row says less than lighting neither.
  def leader(stat, left_value, right_value)
    return if stat.better.nil? || left_value.nil? || right_value.nil? || left_value == right_value

    higher = left_value > right_value
    higher == (stat.better == :high) ? :left : :right
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
