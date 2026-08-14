# Everything we hold on the two sides, laid out so they can be read across.
#
# The cards above answer the question. This is the working underneath it: the same
# figures FPL publishes and the same ones our forecast reads, so a manager who
# disagrees with the pick can see exactly what it was made from.
#
# A side is a player, or the players you would buy together, and a figure for two men
# is not always the two figures added up. See Stat#aggregate.
#
# A row is only drawn when at least one side has the figure. A keeper's saves and a
# forward's goals are both here, and neither leaves an empty line on the other man's
# page.
class ComparisonStats < ApplicationService
  # What a figure is worth reading as.
  #
  # `better` says which way is good: :high for a figure you want more of, :low for one
  # you want less of, nil where it is a fact about a player rather than a mark out of
  # ten.
  #
  # `aggregate` says how two players on one side are read as one figure:
  #
  #   :sum (the default)  a total, or anything earned per gameweek. You own both, so
  #                       you collect both, and they add.
  #   :per_90_mean        a rate over ninety minutes, which cannot be added. It is
  #                       what the pair did between them, so each man's rate counts
  #                       for as much football as `weight` says he played.
  #   :each               neither. A share of the game's managers and a place in a
  #                       penalty queue belong to one man, so each is written out and
  #                       the row favours nobody.
  Stat = Struct.new(:key, :label, :format, :better, :aggregate, :weight, keyword_init: true)

  # What a side reads as for one figure: the number the sides are ranked on, and the
  # way it is written down. The two differ only where a figure cannot be added up.
  Reading = Struct.new(:value, :text, keyword_init: true)

  MINUTES = "season_minutes".freeze
  LAST_SEASON_MINUTES = "last_season_minutes".freeze

  Row = Struct.new(:label, :left, :right, :leader, keyword_init: true)

  Group = Struct.new(:title, :rows, keyword_init: true)

  # What we expect of them, which is the only part of this table about the season
  # being forecast. Everything below it is a record of football already played, and
  # until a ball is kicked that record is last season's however it is labelled.
  #
  # It leads the table because it is the answer. The rows underneath are the working.
  EXPECTED = "What we expect".freeze

  EXPECTED_POINTS = [
    Stat.new(key: Horizon::GAMEWEEK, label: "This gameweek", format: :one, better: :high),
    Stat.new(key: Horizon::UPCOMING, label: "Next #{Horizon::WINDOW} gameweeks", format: :one, better: :high),
    Stat.new(key: Horizon::SEASON, label: "Rest of season", format: :whole, better: :high)
  ].freeze

  # Drawn only once there is a season to describe. FPL leaves last season's totals
  # in the current-season fields all summer, so before the first gameweek this group
  # is last season's record wearing this season's name, which is exactly the reading
  # that makes the page argue with itself.
  THIS_SEASON = "This season".freeze

  GROUPS = {
    THIS_SEASON => [
      Stat.new(key: "season_points", label: "Total points", format: :whole, better: :high),
      Stat.new(key: "points_per_game", label: "Points per game", format: :one, better: :high),
      Stat.new(key: "form", label: "Form", format: :one, better: :high),
      Stat.new(key: "season_minutes", label: "Minutes", format: :whole, better: :high),
      Stat.new(key: "starts_per_90", label: "Starts per 90", format: :two, better: :high,
               aggregate: :per_90_mean, weight: MINUTES),
      Stat.new(key: "season_bonus", label: "Bonus points", format: :whole, better: :high)
    ],
    "Underlying numbers, per 90" => [
      Stat.new(key: "expected_goals_per_90", label: "Expected goals", format: :two, better: :high,
               aggregate: :per_90_mean, weight: MINUTES),
      Stat.new(key: "expected_assists_per_90", label: "Expected assists", format: :two, better: :high,
               aggregate: :per_90_mean, weight: MINUTES),
      Stat.new(key: "expected_goals_conceded_per_90", label: "Expected goals conceded", format: :two, better: :low,
               aggregate: :per_90_mean, weight: MINUTES),
      Stat.new(key: "clean_sheets_per_90", label: "Clean sheets", format: :two, better: :high,
               aggregate: :per_90_mean, weight: MINUTES),
      Stat.new(key: "saves_per_90", label: "Saves", format: :two, better: :high,
               aggregate: :per_90_mean, weight: MINUTES),
      Stat.new(key: "defensive_contribution_per_90", label: "Defensive contributions", format: :two, better: :high,
               aggregate: :per_90_mean, weight: MINUTES)
    ],
    "What the market says" => [
      Stat.new(key: "now_cost", label: "Price", format: :price, better: :low),
      Stat.new(key: "selected_by_percent", label: "Owned by", format: :percent, better: nil, aggregate: :each),
      Stat.new(key: "transfers_in", label: "Transfers in this week", format: :whole, better: nil),
      Stat.new(key: "transfers_out", label: "Transfers out this week", format: :whole, better: nil)
    ],
    "Set pieces" => [
      Stat.new(key: "penalties_order", label: "Penalties", format: :order, better: :low, aggregate: :each),
      Stat.new(key: "direct_freekicks_order", label: "Direct free kicks", format: :order, better: :low,
               aggregate: :each),
      Stat.new(key: "corners_freekicks_order", label: "Corners and indirect free kicks", format: :order,
               better: :low, aggregate: :each)
    ],
    "Last season" => [
      Stat.new(key: "last_season_points", label: "Total points", format: :whole, better: :high),
      Stat.new(key: "last_season_minutes", label: "Minutes", format: :whole, better: :high),
      Stat.new(key: "last_season_expected_goals_per_90", label: "Expected goals per 90", format: :two, better: :high,
               aggregate: :per_90_mean, weight: LAST_SEASON_MINUTES),
      Stat.new(key: "last_season_expected_goal_involvements_per_90", label: "Expected goals and assists per 90",
               format: :two, better: :high, aggregate: :per_90_mean, weight: LAST_SEASON_MINUTES),
      Stat.new(key: "last_season_clean_sheets_per_90", label: "Clean sheets per 90", format: :two, better: :high,
               aggregate: :per_90_mean, weight: LAST_SEASON_MINUTES),
      Stat.new(key: "last_season_saves_per_90", label: "Saves per 90", format: :two, better: :high,
               aggregate: :per_90_mean, weight: LAST_SEASON_MINUTES),
      Stat.new(key: "last_season_bonus", label: "Bonus points", format: :whole, better: :high)
    ]
  }.freeze

  TENTHS_PER_MILLION = 10.0

  def initialize(left:, right:)
    @left = Comparison::Side.wrap(left)
    @right = Comparison::Side.wrap(right)
  end

  def call
    [ expected_group, *recorded_groups ].compact
  end

  private

  attr_reader :left, :right

  def expected_group
    group_of(EXPECTED, EXPECTED_POINTS, forecasts)
  end

  def recorded_groups
    GROUPS.filter_map do |title, stats|
      next if title == THIS_SEASON && !season_started?

      group_of(title, stats, readings)
    end
  end

  def group_of(title, stats, source)
    rows = stats.filter_map { |stat| row_for(stat, source) }
    Group.new(title: title, rows: rows) if rows.any?
  end

  def row_for(stat, source)
    return unless recorded?(stat, source)

    left_reading, right_reading = sides.map { |side| reading_for(stat, side, source) }
    Row.new(label: stat.label, leader: leader(stat, left_reading.value, right_reading.value),
            left: left_reading.text, right: right_reading.text)
  end

  # Somebody has the figure. A keeper's saves and a forward's goals are both in the
  # table, and neither leaves an empty line on the other man's page.
  def recorded?(stat, source)
    sides.any? { |side| raw(stat, side, source).any? }
  end

  def sides = [ left, right ]

  # What one side reads as for one figure. A side of one reads as the man on it, so a
  # comparison of two players is the comparison it always was.
  def reading_for(stat, side, source)
    values = raw(stat, side, source)
    return Reading.new(value: values.first, text: display(stat, values.first)) if side.single?

    case stat.aggregate
    when :each then Reading.new(value: nil, text: values.map { |value| display(stat, value) }.join(" and "))
    when :per_90_mean then reading_of(stat, weighted(stat, side, values, source))
    else reading_of(stat, summed(values))
    end
  end

  def reading_of(stat, value)
    Reading.new(value: value, text: display(stat, value))
  end

  def raw(stat, side, source)
    side.players.map { |player| source.dig(player.id, stat.key) }
  end

  # A total is only a total when we have all of it. A side missing one man's figure is
  # left blank rather than reported as the other man's, which would read as the pair's.
  def summed(values)
    values.sum if values.all?
  end

  # A rate per ninety minutes is not two rates added together. It is what the side did
  # between them, so each man's rate counts for as much football as he played. With no
  # minutes to weigh them by, they are simply averaged.
  def weighted(stat, side, values, source)
    return unless values.all?

    minutes = minutes_for(stat, side, source)
    return values.sum / values.size if minutes.sum.zero?

    values.zip(minutes).sum { |value, played| value * played } / minutes.sum
  end

  def minutes_for(stat, side, source)
    side.players.map { |player| source.dig(player.id, stat.weight).to_f }
  end

  def season_started?
    Gameweek.finished.any?
  end

  # What we expect of each of them at each distance, keyed the way the readings are
  # so that one row builder draws both.
  def forecasts
    @forecasts ||= Forecast.where(gameweek: Gameweek.next_gameweek, player_id: player_ids)
                           .each_with_object({}) do |forecast, by_player|
      (by_player[forecast.player_id] ||= {})[forecast.horizon] = forecast.score.to_f
    end
  end

  # Which of the two the figure favours, where the figure favours anybody. Equal is
  # nobody: lighting both sides of a row says less than lighting neither.
  def leader(stat, left_value, right_value)
    return unless stat.better
    return if left_value.nil? || right_value.nil? || left_value == right_value

    higher = left_value > right_value
    wanted_high = stat.better == :high
    higher == wanted_high ? :left : :right
  end

  def display(stat, value)
    return "—" if value.nil?

    case stat.format
    when :whole then value.round.to_s
    when :one then format("%.1f", value)
    when :two then format("%.2f", value)
    when :price then format("£%.1fm", value / TENTHS_PER_MILLION)
    when :percent then format("%.1f%%", value)
    when :order then ordinal(value)
    else value.to_s
    end
  end

  # FPL numbers set-piece takers 1, 2, 3 from the front, so first is best.
  def ordinal(value)
    { 1 => "1st", 2 => "2nd", 3 => "3rd" }.fetch(value.round, "#{value.round}th")
  end

  def readings
    @readings ||= Statistic.where(player_id: player_ids).latest_by_player
  end

  def player_ids
    (left.players + right.players).map(&:id)
  end
end
