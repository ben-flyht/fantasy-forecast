class ConsensusRanking
  def self.for_week_and_position(gameweek, position = nil, team_id = nil)
    new(gameweek, position, team_id).rankings
  end

  def initialize(gameweek, position = nil, team_id = nil)
    @gameweek = gameweek
    @position = position
    @team_id = team_id
  end

  def rankings
    # Get forecast scores for players who have been forecasted
    forecast_scores = forecast_scores_by_player

    # Get all players for this position
    players = base_players_query

    # Combine base scores with forecast adjustments
    rankings = players.map do |player|
      forecast_data = forecast_scores[player.id] || { score: 0, votes: 0 }

      Ranking.new(
        player_id: player.id,
        name: player.short_name,
        first_name: player.first_name,
        last_name: player.last_name,
        team: player.team&.short_name || "No Team",
        team_id: player.team_id,
        position: player.position,
        consensus_score: forecast_data[:score],
        total_forecasts: forecast_data[:votes],
        total_score: player.total_score(@gameweek - 1)
      )
    end

    # If no forecasts have been made, sort by total score then alphabetically by name
    # Otherwise, sort by total forecasts (descending), then total score (descending), then name
    if forecast_scores.empty?
      rankings.sort_by { |ranking| [ -(ranking.total_score || 0), ranking.name || "" ] }
    else
      rankings.sort_by { |ranking| [ -(ranking.total_forecasts || 0), -(ranking.total_score || 0), ranking.name || "" ] }
    end
  end

  private

  attr_reader :gameweek, :position, :team_id

  def base_players_query
    query = Player.includes(:team)
    query = query.where(position: position) if position.present?
    query = query.where(team_id: team_id) if team_id.present?
    query
  end

  def forecast_scores_by_player
    forecasts = Forecast.joins(:gameweek)
                       .where(gameweeks: { fpl_id: @gameweek })
                       .group(:player_id)
                       .select(
                         "player_id",
                         "COUNT(*) as votes"
                       )

    forecasts.each_with_object({}) do |forecast, hash|
      hash[forecast.player_id] = {
        score: forecast.votes,
        votes: forecast.votes
      }
    end
  end
end
