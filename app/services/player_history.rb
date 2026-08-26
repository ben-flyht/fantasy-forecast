# What this player has done, and what we have been saying about him.
#
# Everything here is a series rather than a reading, which is the point: a single
# figure says where a player is, and only a run of them says which way he is
# going. A forecast that has climbed twenty places in a fortnight is a different
# proposition from the same forecast standing still.
#
# All of it is empty until the football starts, and each part says so on its own
# rather than leaving the page with a heading and nothing under it.
class PlayerHistory < ApplicationService
  # A blank is a week he was available for and got nothing out of. Two points is
  # the bare appearance, so anything at or under it is a week that did nothing for
  # anybody who owned him.
  BLANK = 2

  COST = "now_cost".freeze

  # FPL holds prices in tenths of a million.
  TENTHS_PER_MILLION = 10.0

  # What is worth watching over time, by where he plays. A goalkeeper's saves are
  # his living and a forward's are nobody's business, so the page shows each
  # position the rates that decide its returns.
  TRENDS = {
    "goalkeeper" => {
      "saves_per_90" => "Saves per 90",
      "clean_sheets_per_90" => "Clean sheets per 90",
      "expected_goals_conceded_per_90" => "Goals conceded per 90"
    },
    "defender" => {
      "clean_sheets_per_90" => "Clean sheets per 90",
      "defensive_contribution_per_90" => "Defensive actions per 90",
      "expected_goal_involvements_per_90" => "Goal involvements per 90"
    },
    "midfielder" => {
      "expected_goals_per_90" => "Expected goals per 90",
      "expected_goal_involvements_per_90" => "Goal involvements per 90",
      "defensive_contribution_per_90" => "Defensive actions per 90"
    },
    "forward" => {
      "expected_goals_per_90" => "Expected goals per 90",
      "expected_goal_involvements_per_90" => "Goal involvements per 90"
    }
  }.freeze

  Point = Struct.new(:gameweek, :value, keyword_init: true)

  Trend = Struct.new(:label, :points, keyword_init: true) do
    def latest
      points.last&.value
    end

    # A flat line is not a trend, and neither is a single reading.
    def moving?
      points.many? && points.map(&:value).uniq.many?
    end
  end

  def initialize(player:, horizon:)
    @player = player
    @horizon = horizon
  end

  def call
    self
  end

  # Where we have ranked him, week by week, over the horizon on show.
  def ranks
    @ranks ||= @player.forecasts.where(horizon: @horizon).joins(:gameweek)
                      .where.not(rank: nil).order("gameweeks.fpl_id")
                      .pluck(Arel.sql("gameweeks.fpl_id"), :rank)
                      .map { |fpl_id, rank| Point.new(gameweek: fpl_id, value: rank) }
  end

  # Places gained since the previous forecast. Positive is upward, because a rank
  # improves by getting smaller and nobody reads "-8" as good news.
  def rank_change
    return unless ranks.many?

    ranks[-2].value - ranks[-1].value
  end

  def points
    @points ||= @player.performances.joins(:gameweek).order("gameweeks.fpl_id")
                       .pluck(Arel.sql("gameweeks.fpl_id"), :gameweek_score)
                       .map { |fpl_id, score| Point.new(gameweek: fpl_id, value: score) }
  end

  def played?
    points.any?
  end

  def total_points
    points.sum(&:value)
  end

  def best_week
    points.max_by(&:value)
  end

  # Weeks he played and returned nothing worth having.
  def blanks
    points.count { |point| point.value <= BLANK }
  end

  # Points per million: what the return has cost. Nil before he has scored any, or
  # where we have no price for him.
  def points_per_million
    return if !played? || cost.nil? || cost.zero?

    total_points / (cost / TENTHS_PER_MILLION)
  end

  # The rates behind his returns, week by week, for the position he plays.
  def trends
    @trends ||= TRENDS.fetch(@player.position, {}).filter_map do |type, label|
      trend = Trend.new(label: label, points: series[type] || [])
      trend if trend.moving?
    end
  end

  # What he has cost over the season. A price is one reading a week and every
  # manager watches it, so it earns its place among the rates.
  def price_history
    @price_history ||= Trend.new(label: "Price", points: series[COST] || [])
  end

  private

  def cost
    price_history.latest
  end

  def series
    @series ||= Statistic.where(player_id: @player.id, type: TRENDS.fetch(@player.position, {}).keys + [ COST ])
                         .joins(:gameweek).order("gameweeks.fpl_id")
                         .pluck(:type, Arel.sql("gameweeks.fpl_id"), :value)
                         .group_by(&:first)
                         .transform_values do |rows|
                           rows.map { |_type, fpl_id, value| Point.new(gameweek: fpl_id, value: value.to_f) }
                         end
  end
end
