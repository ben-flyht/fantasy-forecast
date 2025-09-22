class ConsensusRanking
  def self.for_week_and_position(week, position = nil)
    new(week, position).rankings
  end

  def initialize(week, position = nil)
    @week = week
    @position = position
  end

  def rankings
    # Get forecast scores for players who have been forecasted
    forecast_scores = forecast_scores_by_player

    # Get all players for this position
    players = base_players_query

    # Combine base scores with forecast adjustments
    players.map do |player|
      forecast_data = forecast_scores[player.id] || { score: 0, votes: 0 }

      Ranking.new(
        player_id: player.id,
        name: player.short_name,
        first_name: player.first_name,
        last_name: player.last_name,
        team: player.team,
        position: player.position,
        consensus_score: forecast_data[:score],
        total_forecasts: forecast_data[:votes],
        ownership_percentage: player.ownership_percentage
      )
    end.sort_by { |ranking| [-ranking.consensus_score, -ranking.ownership_percentage.to_f] }
  end

  private

  attr_reader :week, :position

  def base_players_query
    query = Player.all
    query = query.where(position: position) if position.present?
    query
  end

  def forecast_scores_by_player
    forecasts = Forecast.joins(:gameweek)
                       .where(gameweeks: { fpl_id: week })
                       .group(:player_id)
                       .select(
                         'player_id',
                         'SUM(CASE WHEN category = \'target\' THEN 1 WHEN category = \'avoid\' THEN -1 ELSE 0 END) as score',
                         'COUNT(*) as votes'
                       )

    forecasts.each_with_object({}) do |forecast, hash|
      hash[forecast.player_id] = {
        score: forecast.score,
        votes: forecast.votes
      }
    end
  end

end