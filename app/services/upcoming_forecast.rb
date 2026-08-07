# What every player is expected to score over the next few gameweeks, stored against
# the coming one as its anchor. See Forecaster for the how and the why.
#
# This is the horizon a transfer is actually made over. The weekly forecast answers
# who to captain and the season one answers who to hold, but neither answers the
# question a manager spends his transfers on: who is worth owning for the run of
# fixtures in front of him.
#
# It is also the horizon this model is least naive about. A season total applies
# today's form, price and availability the whole way to May, which the season
# forecast admits is "progressively less honest the further ahead you read". Over
# five weeks that snapshot is still broadly true, so the same arithmetic is doing far
# less pretending here than it does there.
class UpcomingForecast < Forecaster
  # Both of these sit between the two horizons either side of it, because that is
  # honestly where five weeks sits.
  #
  # The band a record may pull a player off his price is drawn a little tighter than
  # the coming week's 0.05 and wider than the season's 0.03. A returning star earns
  # his price back over a season and not over one weekend; over five weeks he is
  # partway there.
  CLAMP_WIDTH = 0.04

  # A new signing's record is capped at half a match in the coming week and let up to
  # three quarters over a season, by when he will long since have settled. Five weeks
  # is most of a settling-in period, so it lands between.
  NEW_CLUB_MINUTES = 0.6

  private

  def horizon
    Horizon::UPCOMING
  end

  def matches
    Match.includes(:home_team, :away_team).where(gameweek: window)
  end

  # The horizon itself, asked for once: both the fixtures it spans and the fitness it
  # is read over are the same run of gameweeks.
  def window
    @window ||= Horizon.new(Horizon::UPCOMING).gameweeks.to_a
  end

  def model_overrides
    { clamp_width: CLAMP_WIDTH, new_club_minutes: NEW_CLUB_MINUTES }
  end
end
