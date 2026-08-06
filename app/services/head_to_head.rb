# Two players, and the question every manager actually types into a search box:
# him or him?
#
# The rankings answer it a hundred rows at a time, which is the wrong shape for
# somebody who has already narrowed it to two. This puts the pair side by side and
# says which one, out loud, from the same stored forecast the rankings are read
# from, so the two can never disagree.
#
# It will decline to answer. Our forecast is a number with a margin of error we
# have not measured yet, and a tenth of a point between two players is not a
# reason to make a transfer. Below CLOSE the honest answer is that there is
# nothing to choose between them.
class HeadToHead < ApplicationService
  # How much better one player has to look, in a single week's points, before the
  # difference is worth acting on rather than an artefact of the arithmetic.
  CLOSE = 0.25

  COST = "now_cost".freeze
  OWNERSHIP = "selected_by_percent".freeze

  SEASON = "season".freeze

  Side = Struct.new(:player, :score, :rank, :grade, :tier, :cost, :ownership, :match,
                    keyword_init: true) do
    def forecast?
      !score.nil?
    end

    def home?
      match && match.home_team_id == player.team_id
    end

    def opponent
      return unless match

      home? ? match.away_team : match.home_team
    end
  end

  def initialize(left:, right:, gameweek:, horizon: "gameweek")
    @left_player = left
    @right_player = right
    @gameweek = gameweek
    @horizon = horizon
  end

  def call
    self
  end

  attr_reader :gameweek, :horizon

  def left
    @left ||= side_for(@left_player)
  end

  def right
    @right ||= side_for(@right_player)
  end

  def sides
    [ left, right ]
  end

  # The one we would have, or nothing if the pair are too close to separate.
  def winner
    return if tie?

    ranked.first
  end

  def loser
    return if tie?

    ranked.last
  end

  # Neither has a forecast, or they are close enough that picking between them on
  # our numbers would be a false precision.
  def tie?
    return true unless left.forecast? && right.forecast?

    margin < CLOSE
  end

  # How far apart they are, in the points of a single week.
  def margin
    return 0.0 unless left.forecast? && right.forecast?

    ((weekly(left.score) - weekly(right.score)).abs).round(2)
  end

  def season?
    @horizon == SEASON
  end

  # When the numbers on the page were last worked out, so a card drawn from them
  # can be kept until they change.
  def forecast_at
    forecasts.values.map(&:updated_at).max
  end

  private

  def ranked
    [ left, right ].sort_by { |side| -(side.score || -1) }
  end

  def side_for(player)
    Side.new(
      player: player, match: matches[player.team_id],
      cost: facts.dig(player.id, COST), ownership: facts.dig(player.id, OWNERSHIP),
      **scored(forecasts[player.id])
    )
  end

  # What the forecast says about him, graded on the scale a single week is read
  # on. A player we have no forecast for is left blank rather than marked nought.
  def scored(forecast)
    score = forecast&.score&.to_f
    return { score: nil, rank: nil, grade: nil, tier: nil } if score.nil?

    { score: score, rank: forecast.rank,
      grade: TierCalculator.grade_from_points(weekly(score)),
      tier: TierCalculator.tier_from_points(weekly(score)) }
  end

  # A rest-of-season score is dozens of points where a week's is two to four, so
  # it is read as the week it averages to before it is graded or compared. Both
  # horizons then answer on the same scale.
  def weekly(score)
    return 0.0 if score.nil?

    score / (season? ? Gameweek.remaining_count : 1)
  end

  def forecasts
    @forecasts ||= Forecast.where(gameweek: @gameweek, horizon: @horizon, player: players)
                           .index_by(&:player_id)
  end

  def facts
    @facts ||= Statistic.where(player_id: players.map(&:id), type: [ COST, OWNERSHIP ])
                        .latest_by_player
  end

  # Who each of them is playing this week, so the page can say why the numbers
  # differ rather than only that they do.
  def matches
    @matches ||= begin
      team_ids = players.filter_map(&:team_id)
      Match.includes(:home_team, :away_team)
           .where(gameweek: @gameweek)
           .where("home_team_id IN (:ids) OR away_team_id IN (:ids)", ids: team_ids)
           .each_with_object({}) do |match, by_team|
             by_team[match.home_team_id] = match
             by_team[match.away_team_id] = match
           end
    end
  end

  def players
    [ @left_player, @right_player ]
  end
end
