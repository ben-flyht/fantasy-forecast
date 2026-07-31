# What every player is expected to score in the coming gameweek, over that single
# week's fixtures. See Forecaster for the how and the why.
class WeeklyForecast < Forecaster
  private

  def horizon
    "gameweek"
  end

  def matches
    Match.includes(:home_team, :away_team).where(gameweek: @gameweek)
  end
end
