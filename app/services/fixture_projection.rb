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

  def initialize(player:, matches:, anchor_score:, anchor_worth:, next_gameweek_id:)
    @player = player
    @matches = matches
    @anchor_score = anchor_score
    @anchor_worth = anchor_worth
    @next_gameweek_id = next_gameweek_id
  end

  def call
    @matches.map do |match|
      Row.new(match: match, points: points_for(match), projected: match.gameweek_id != @next_gameweek_id)
    end
  end

  private

  def points_for(match)
    return unless base

    (base * engine.fixture_worth(ranking, fixture_for(match))).round(1)
  end

  def base
    return @base if defined?(@base)

    @base = @anchor_score && @anchor_worth.to_f.positive? ? @anchor_score / @anchor_worth : nil
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
    @stats ||= Statistic.where(player_id: @player.id, type: ExpectedPoints::STAT_TYPES)
                        .order(:gameweek_id)
                        .pluck(:type, :value)
                        .each_with_object(@player.id => {}) { |(type, value), out| out[@player.id][type] = value.to_f }
  end
end
