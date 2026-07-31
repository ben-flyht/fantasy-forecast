# Returns bot rankings for a given gameweek and position.
# Simplified from the original consensus system now that we only have bot forecasts.
class ConsensusRanking
  Ranking = Struct.new(:player_id, :name, :team_id, :position, :bot_rank, :score, :tier, keyword_init: true)

  def self.for_week_and_position(gameweek, position = nil, team_id = nil, horizon: "gameweek")
    new(gameweek, position, team_id, horizon: horizon).rankings
  end

  def initialize(gameweek, position = nil, team_id = nil, horizon: "gameweek")
    @gameweek = gameweek
    @position = position
    @team_id = team_id
    @horizon = horizon
  end

  def rankings
    return [] unless gameweek_record

    build_rankings
  end

  private

  def gameweek_record
    @gameweek_record ||= Gameweek.find_by(fpl_id: @gameweek)
  end

  def build_rankings
    ranked, unranked = forecasts.partition { |f| f.rank.present? }
    build_ranked_results(ranked) + build_unranked_results(unranked)
  end

  def build_ranked_results(forecasts)
    forecasts.sort_by(&:rank).map { |f| build_ranking(f) }
  end

  def build_unranked_results(forecasts)
    forecasts.sort_by { |f| f.player.short_name.downcase }.map { |f| build_ranking(f) }
  end

  def forecasts
    scope = Forecast.includes(player: :team).where(gameweek: gameweek_record, horizon: @horizon)
    scope = scope.joins(:player).where(players: { position: @position }) if @position.present?
    scope = scope.joins(:player).where(players: { team_id: @team_id }) if @team_id.present?
    scope
  end

  def build_ranking(forecast)
    player = forecast.player

    Ranking.new(
      **player_attributes(player),
      bot_rank: forecast.rank,
      score: forecast.score
    )
  end

  def player_attributes(player)
    { player_id: player.id, name: player.short_name, team_id: player.team_id, position: player.position }
  end
end
