# The performance underneath the answer: what each side does per 90 minutes, laid out
# so the two can be read across.
#
# The cards above already say what we expect of each side and what it costs, so this is
# not that. It is the record a manager weighs a trade on — goals, assists, the defensive
# work, how reliably they start — and nothing we forecast, only what has happened.
#
# Before a ball is kicked this season the record is last season's, because there is no
# other; once the season is under way it is this season's. Either way it is per 90, and
# a side is worth what its players do between them, so the rates are summed.
class ComparisonStats < ApplicationService
  # `this`/`last` are the stored figures for each season; `last` is nil where FPL did
  # not keep it last season, and that row simply waits until the season provides it.
  # `better` says which way is good.
  Stat = Struct.new(:this, :last, :label, :better, keyword_init: true)

  Reading = Struct.new(:value, :text, keyword_init: true)

  Row = Struct.new(:label, :left, :right, :leader, keyword_init: true)

  Group = Struct.new(:title, :rows, keyword_init: true)

  PER_90 = [
    Stat.new(this: "expected_goals_per_90", last: "last_season_expected_goals_per_90",
             label: "Expected goals", better: :high),
    Stat.new(this: "expected_goal_involvements_per_90", last: "last_season_expected_goal_involvements_per_90",
             label: "Expected goals and assists", better: :high),
    Stat.new(this: "expected_goals_conceded_per_90", last: nil,
             label: "Expected goals conceded", better: :low),
    Stat.new(this: "clean_sheets_per_90", last: "last_season_clean_sheets_per_90",
             label: "Clean sheets", better: :high),
    Stat.new(this: "saves_per_90", last: "last_season_saves_per_90",
             label: "Saves", better: :high),
    Stat.new(this: "defensive_contribution_per_90", last: nil,
             label: "Defensive contributions", better: :high),
    Stat.new(this: "starts_per_90", last: nil,
             label: "Starts", better: :high)
  ].freeze

  def initialize(left:, right:)
    @left = Comparison::Side.wrap(left)
    @right = Comparison::Side.wrap(right)
  end

  def call
    rows = PER_90.filter_map { |stat| row_for(stat) }
    return [] if rows.empty?

    [ Group.new(title: title, rows: rows) ]
  end

  private

  attr_reader :left, :right

  def title
    season_started? ? "This season, per 90" : "Last season, per 90"
  end

  def row_for(stat)
    key = season_started? ? stat.this : stat.last
    return if key.nil?

    readings = sides.map { |side| reading_for(side, key) }
    row_of(stat, *readings) if readings.any?(&:value)
  end

  def row_of(stat, left_reading, right_reading)
    Row.new(label: stat.label, leader: leader(stat, left_reading.value, right_reading.value),
            left: left_reading.text, right: right_reading.text)
  end

  def sides = [ left, right ]

  # A side is worth what everybody on it does between them, so the rates are summed. A
  # total is only a total when we have all of it: a side missing one man's figure is
  # left blank rather than reported as the rest of the side without him.
  def reading_for(side, key)
    values = side.players.map { |player| readings.dig(player.id, key) }
    total = values.sum if values.all?
    Reading.new(value: total, text: display(total))
  end

  # Which side the figure favours, where it favours anybody. Equal is nobody: lighting
  # both sides of a row says less than lighting neither.
  def leader(stat, left_value, right_value)
    return if left_value.nil? || right_value.nil? || left_value == right_value

    higher = left_value > right_value
    higher == (stat.better == :high) ? :left : :right
  end

  def display(value)
    return "—" if value.nil?

    format("%.2f", value)
  end

  def season_started?
    Gameweek.finished.any?
  end

  def readings
    @readings ||= Statistic.where(player_id: (left.players + right.players).map(&:id)).latest_by_player
  end
end
