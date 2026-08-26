# Expected points for a player's run of upcoming fixtures.
#
# Only the next gameweek is ever truly forecast, so that score is the anchor and
# the rest are projected from it: each fixture is weighed by what it is worth
# against an ordinary one, using the same fixture maths the forecast itself uses.
# A player who scores 6 against a kind opponent is worth less against a cruel
# one, and a keeper the other way, and that falls out of ExpectedPoints rather
# than being guessed here.
class FixtureProjection < ApplicationService
  Row = Struct.new(:match, :points, :projected, keyword_init: true)

  def initialize(player:, matches:, anchors:, next_gameweek_id:)
    @player = player
    @matches = matches
    @anchors = Array(anchors).compact
    @next_gameweek_id = next_gameweek_id
  end

  def call
    @matches.map do |match|
      Row.new(match: match, points: points_for(match), projected: projected?(match))
    end
  end

  private

  # A nought is a fact about the week it was forecast for and no claim at all
  # about the weeks after it.
  #
  # FPL says a ruled-out player has no chance this Saturday. It says nothing
  # about the Saturday after, and where it gives no return date we assume a long
  # absence by our own admission that it is a guess. Read straight, one week's
  # nought was multiplied out into five: Timber's groin strain came out as 0.0
  # against Chelsea in September, printed five times in a column, which reads as
  # knowledge rather than as caution. Our own rest-of-season forecast for him is
  # ninety-seven points, so it is not even what we think.
  #
  # The week itself keeps its nought, because that one we do know.
  def points_for(match)
    return unless base
    return if base.zero? && projected?(match)

    (base * engine.fixture_worth(ranking, fixture_for(match))).round(1)
  end

  def projected?(match)
    match.gameweek_id != @next_gameweek_id
  end

  # What the player is worth on an ordinary fixture, taken from the first anchor
  # that has a fixture in it: his forecast for the week, divided back out by what
  # that week's opponents were worth to him.
  #
  # A week he does not play is worth nought over nought games, which is a true
  # statement about that week and no answer at all about the ones after it. Asked
  # for the only anchor it had, this used to hand back nothing and empty the whole
  # column, so a blank gameweek hid the run of fixtures exactly when a manager was
  # looking past it. The rest-of-season forecast spans the football he does play,
  # so it answers when the week cannot.
  def base
    return @base if defined?(@base)

    @base = @anchors.filter_map { |anchor| ordinary_worth(anchor) }.first
  end

  def ordinary_worth(anchor)
    games = anchor.working&.dig("games").to_f
    return nil unless anchor.score && games.positive?

    anchor.score / games
  end

  def fixture_for(match)
    { difficulty: match.difficulty_for(@player.team_id), home: match.home_team_id == @player.team_id }
  end

  def ranking
    @ranking ||= ConsensusRanking::Ranking.new(
      player_id: @player.id, position: @player.position, team_id: @player.team_id
    )
  end

  def engine
    @engine ||= ExpectedPoints.new(
      [ ranking ], stats: stats, fixtures_by_team: {},
      season_started: Gameweek.finished.exists?, gameweeks_played: Gameweek.finished.count
    )
  end

  def stats
    @stats ||= Statistic.where(player_id: @player.id, type: ExpectedPoints::STAT_TYPES).latest_by_player
  end
end
