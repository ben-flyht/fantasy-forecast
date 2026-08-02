# What every player is expected to score across all the gameweeks that remain,
# stored against the next one as its anchor. A single pass over the whole run of
# fixtures: a team playing often, or playing weak sides, has more to come and
# scores higher for it. See Forecaster for the how and the why.
#
# This is a naive season total. The transfer, form and availability signals are
# today's snapshot applied the whole way out, which is honest for the next
# gameweek and progressively less so the further ahead you read.
class RestOfSeasonForecast < Forecaster
  # The crowd's order is an early-season reading, so over a whole season it is
  # trusted less and each player's own record does more of the talking.
  CROWD_WEIGHT = 0.85

  # A player who changed clubs will have settled in long before the season is out,
  # so the half-a-match caution on his old minutes is eased for this horizon.
  NEW_CLUB_MINUTES = 0.75

  private

  def horizon
    "rest_of_season"
  end

  def matches
    Match.includes(:home_team, :away_team).where(gameweek: Gameweek.remaining)
  end

  def model_overrides
    { crowd_weight: CROWD_WEIGHT, new_club_minutes: NEW_CLUB_MINUTES }
  end

  # An injury is a spell out, not the end of a career, so over a season a player
  # is worth the share of it he is expected to be fit for rather than nothing at
  # all. See Availability.
  def fitness(players)
    Availability.call(players, gameweeks: Gameweek.remaining)
  end
end
