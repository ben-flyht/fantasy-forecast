# What every player is expected to score across all the gameweeks that remain,
# stored against the next one as its anchor. A single pass over the whole run of
# fixtures: a team playing often, or playing weak sides, has more to come and
# scores higher for it. See Forecaster for the how and the why.
#
# This is a naive season total. The transfer, form and availability signals are
# today's snapshot applied the whole way out, which is honest for the next
# gameweek and progressively less so the further ahead you read.
class RestOfSeasonForecast < Forecaster
  private

  def horizon
    "rest_of_season"
  end

  def matches
    Match.includes(:home_team, :away_team).where(gameweek: Gameweek.remaining)
  end
end
