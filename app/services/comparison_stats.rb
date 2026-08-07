# Everything we hold on two players, laid out so the two can be read across.
#
# The cards above answer the question. This is the working underneath it: the same
# figures FPL publishes and the same ones our forecast reads, so a manager who
# disagrees with the pick can see exactly what it was made from.
#
# A row is only drawn when at least one of the pair has the figure. A keeper's saves
# and a forward's goals are both here, and neither leaves an empty line on the other
# man's page.
class ComparisonStats < ApplicationService
  # What a figure is worth reading as. `better` says which way is good: :high for a
  # figure you want more of, :low for one you want less of, nil where it is a fact
  # about a player rather than a mark out of ten.
  Stat = Struct.new(:key, :label, :format, :better, keyword_init: true)

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
      Stat.new(key: "starts_per_90", label: "Starts per 90", format: :two, better: :high),
      Stat.new(key: "season_bonus", label: "Bonus points", format: :whole, better: :high)
    ],
    "Underlying numbers, per 90" => [
      Stat.new(key: "expected_goals_per_90", label: "Expected goals", format: :two, better: :high),
      Stat.new(key: "expected_assists_per_90", label: "Expected assists", format: :two, better: :high),
      Stat.new(key: "expected_goals_conceded_per_90", label: "Expected goals conceded", format: :two, better: :low),
      Stat.new(key: "clean_sheets_per_90", label: "Clean sheets", format: :two, better: :high),
      Stat.new(key: "saves_per_90", label: "Saves", format: :two, better: :high),
      Stat.new(key: "defensive_contribution_per_90", label: "Defensive contributions", format: :two, better: :high)
    ],
    "What the market says" => [
      Stat.new(key: "now_cost", label: "Price", format: :price, better: :low),
      Stat.new(key: "selected_by_percent", label: "Owned by", format: :percent, better: nil),
      Stat.new(key: "transfers_in", label: "Transfers in this week", format: :whole, better: nil),
      Stat.new(key: "transfers_out", label: "Transfers out this week", format: :whole, better: nil)
    ],
    "Set pieces" => [
      Stat.new(key: "penalties_order", label: "Penalties", format: :order, better: :low),
      Stat.new(key: "direct_freekicks_order", label: "Direct free kicks", format: :order, better: :low),
      Stat.new(key: "corners_freekicks_order", label: "Corners and indirect free kicks", format: :order, better: :low)
    ],
    "Last season" => [
      Stat.new(key: "last_season_points", label: "Total points", format: :whole, better: :high),
      Stat.new(key: "last_season_minutes", label: "Minutes", format: :whole, better: :high),
      Stat.new(key: "last_season_expected_goals_per_90", label: "Expected goals per 90", format: :two, better: :high),
      Stat.new(key: "last_season_expected_goal_involvements_per_90", label: "Expected goals and assists per 90", format: :two, better: :high),
      Stat.new(key: "last_season_clean_sheets_per_90", label: "Clean sheets per 90", format: :two, better: :high),
      Stat.new(key: "last_season_saves_per_90", label: "Saves per 90", format: :two, better: :high),
      Stat.new(key: "last_season_bonus", label: "Bonus points", format: :whole, better: :high)
    ]
  }.freeze

  TENTHS_PER_MILLION = 10.0

  def initialize(left:, right:)
    @left = left
    @right = right
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
    values = readings_for(stat, source)
    return if values.compact.empty?

    Row.new(label: stat.label, leader: leader(stat, *values),
            left: display(stat, values.first), right: display(stat, values.last))
  end

  def readings_for(stat, source)
    [ source.dig(left.id, stat.key), source.dig(right.id, stat.key) ]
  end

  def season_started?
    Gameweek.finished.any?
  end

  # What we expect of each of them at each distance, keyed the way the readings are
  # so that one row builder draws both.
  def forecasts
    @forecasts ||= Forecast.where(gameweek: Gameweek.next_gameweek, player_id: [ left.id, right.id ])
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
    @readings ||= Statistic.where(player_id: [ left.id, right.id ]).latest_by_player
  end
end
