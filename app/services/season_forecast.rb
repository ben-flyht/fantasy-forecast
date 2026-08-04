# What every player is expected to score across all the gameweeks that remain,
# stored against the next one as its anchor. A single pass over the whole run of
# fixtures: a team playing often, or playing weak sides, has more to come and
# scores higher for it. See Forecaster for the how and the why.
#
# This is a naive season total. The transfer, form and availability signals are
# today's snapshot applied the whole way out, which is honest for the next
# gameweek and progressively less so the further ahead you read.
class SeasonForecast < Forecaster
  # A returning star earns his price back over a season, not over one weekend, so
  # the record is let argue less against the market here than in the weekly view,
  # not more: the band a record may pull a player off his price is drawn tighter.
  # An injured man's pre-injury standing, carried in what he still costs, is most
  # deserved exactly over the horizon he will be fit for most of. See CLAMP_WIDTH.
  CLAMP_WIDTH = 0.03

  # A player who changed clubs will have settled in long before the season is out,
  # so the half-a-match caution on his old minutes is eased for this horizon.
  NEW_CLUB_MINUTES = 0.75

  private

  def horizon
    "season"
  end

  def matches
    Match.includes(:home_team, :away_team).where(gameweek: remaining)
  end

  # The horizon itself, asked for once: both the fixtures it spans and the fitness
  # it is read over are the same run of gameweeks.
  def remaining
    @remaining ||= Gameweek.remaining.to_a
  end

  def model_overrides
    { clamp_width: CLAMP_WIDTH, new_club_minutes: NEW_CLUB_MINUTES }
  end

  # An injury is a spell out, not the end of a career, so over a season a player
  # is worth the share of it he is expected to be fit for rather than nothing at
  # all. See Availability.
  def fitness(players)
    Availability.call(players, gameweeks: remaining)
  end
end
