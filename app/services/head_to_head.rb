# Two sides, and the question every manager actually types into a search box: him or
# him? Or, once he has two free transfers in hand: these two, or those two?
#
# The rankings answer it a hundred rows at a time, which is the wrong shape for
# somebody who has already narrowed it down. This puts the sides beside each other and
# says which one, out loud, from the same stored forecast the rankings are read from,
# so the two can never disagree.
#
# A side is a player or the players you would buy together. One of each is the pair
# this started as, and everything a page or a card asks of a side of one is answered
# the way it always was.
class HeadToHead < ApplicationService
  # How much better one player has to look, in a single week's points, before the
  # difference is worth acting on rather than an artefact of the arithmetic.
  CLOSE = 0.25

  COST = "now_cost".freeze
  OWNERSHIP = "selected_by_percent".freeze

  SEASON = "season".freeze

  # What we hold on one player on one side.
  Member = Struct.new(:player, :score, :rank, :grade, :tier, :cost, :ownership, :match,
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

  # One half of the argument, scored.
  #
  # A side of one answers for its player, because a page and a card written for a pair
  # should not have to ask how many players a side holds before it can draw one. A side
  # of two answers for neither: a rank is a place in a position table and a grade is a
  # mark out of ten for a single week, and neither means anything about two men at once.
  class Side
    attr_reader :members

    def initialize(members)
      @members = members
    end

    def single? = members.one?

    def size = members.size

    def players = members.map(&:player)

    def player = only&.player

    def rank = only&.rank

    def grade = only&.grade

    def tier = only&.tier

    def match = only&.match

    def ownership = only&.ownership

    def home? = only&.home?

    def opponent = only&.opponent

    # A side is worth what everybody on it is worth.
    #
    # A player we cannot forecast leaves the whole side unforecast rather than counting
    # as nought. A pair that quietly drops a man and still shows a number is worse than
    # a pair with no number at all.
    def forecast?
      members.all?(&:forecast?)
    end

    def score
      members.sum(&:score) if forecast?
    end

    def cost
      prices = members.map(&:cost)
      prices.sum if prices.all?
    end

    private

    def only
      members.first if single?
    end
  end

  def initialize(left:, right:, gameweek:, horizon: "gameweek")
    @left_side = Comparison::Side.wrap(left)
    @right_side = Comparison::Side.wrap(right)
    @gameweek = gameweek
    @horizon = horizon
  end

  def call
    self
  end

  attr_reader :gameweek, :horizon

  def left
    @left ||= side_for(@left_side)
  end

  def right
    @right ||= side_for(@right_side)
  end

  def sides
    [ left, right ]
  end

  # The one we would have. Always answers where there is a forecast to answer from,
  # even by a hundredth of a point.
  #
  # We used to decline below CLOSE, which was honest and useless: a manager with two
  # names and one transfer has to pick one of them, and "too close to call" sends him
  # away to guess. So the pick is always named and the margin is reported alongside
  # it, which lets him weigh the answer rather than not have one.
  def pick
    return unless forecast?

    ranked.first
  end

  def runner_up
    return unless forecast?

    ranked.last
  end

  # The one we would have, when we would have one strongly enough to say so without
  # qualification. See #close? for the rest.
  def winner
    return if tie?

    ranked.first
  end

  def loser
    return if tie?

    ranked.last
  end

  # Both sides have a forecast, so there is something to compare at all.
  def forecast?
    left.forecast? && right.forecast?
  end

  # Neither has a forecast, or they are close enough that picking between them on
  # our numbers would be a false precision.
  def tie?
    return true unless forecast?

    close?
  end

  # A pick we would not argue hard for: the gap is smaller than the difference our
  # forecast can honestly claim to see.
  def close?
    return false unless forecast?

    margin < close_enough
  end

  # How far apart they are, in the points of a single week.
  def margin
    return 0.0 unless forecast?

    ((weekly(left.score) - weekly(right.score)).abs).round(2)
  end

  # The gap two sides have to clear before we will argue for one of them.
  #
  # CLOSE is the smallest difference we can see between two players. Two players carry
  # two players' worth of error, and errors that are independent add in quadrature, so
  # the threshold grows with the root of the side rather than with the side: two pairs
  # have to be about a third of a point apart, not half of one.
  def close_enough
    CLOSE * Math.sqrt(sides.map(&:size).max)
  end

  # Both sides hold the same number of players, so the comparison is like for like.
  # Three players score more than two, and a page must not let the bigger side win on
  # that alone.
  def level?
    left.size == right.size
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

  def side_for(side)
    Side.new(side.players.map { |player| member_for(player) })
  end

  def member_for(player)
    Member.new(
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

  # A rest-of-season score is dozens of points where a week's is two to four, so it is
  # read as the week it averages to before it is graded or compared. Every horizon then
  # answers on the same scale, whichever distance it was worked out over.
  def weekly(score)
    return 0.0 if score.nil?

    score / Horizon.find(@horizon).divisor
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
    @left_side.players + @right_side.players
  end
end
