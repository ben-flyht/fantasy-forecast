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
    # Otherwise, sort by adjusted consensus score (descending), then total score (descending), then name
    if forecast_scores.empty?
      rankings.sort_by { |ranking| [ -(ranking.total_score || 0), ranking.name || "" ] }
    else
      rankings.sort_by { |ranking| [ -(ranking.consensus_score || 0), -(ranking.total_score || 0), ranking.name || "" ] }
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
    # Get forecaster accuracy scores (only those with at least 25% accuracy)
    forecaster_rankings = ForecasterRankings.overall
                                            .select { |r| r[:accuracy_score] >= 0.25 }
                                            .map { |r| [ r[:user_id], r[:accuracy_score] ] }
                                            .to_h

    # If no qualified forecasters, return empty hash (no consensus)
    return {} if forecaster_rankings.empty?

    # Get all forecasts for this gameweek from qualified forecasters
    forecasts = Forecast.joins(:gameweek)
                       .where(gameweeks: { fpl_id: @gameweek })
                       .where(user_id: forecaster_rankings.keys)
                       .select(:player_id, :user_id)

    # Calculate weighted scores by player
    player_scores = Hash.new { |h, k| h[k] = { weighted_score: 0.0, vote_count: 0 } }

    forecasts.each do |forecast|
      accuracy_weight = forecaster_rankings[forecast.user_id]
      player_scores[forecast.player_id][:weighted_score] += accuracy_weight
      player_scores[forecast.player_id][:vote_count] += 1
    end

    # Return hash with weighted scores
    player_scores.transform_values do |data|
      {
        score: data[:weighted_score],
        votes: data[:vote_count]
      }
    end
  end
end
