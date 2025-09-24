class ForecasterRankings
  def self.overall
    # Get all forecasts with their gameweek data for weighting
    forecasts_with_weights = calculate_weighted_scores

    # Group by user and aggregate weighted scores
    user_scores = forecasts_with_weights.group_by { |f| f[:user_id] }.map do |user_id, user_forecasts|
      user = User.find(user_id)

      total_weighted_score = user_forecasts.sum { |f| f[:weighted_score] }
      total_raw_score = user_forecasts.sum { |f| f[:total_score] }
      total_accuracy = user_forecasts.sum { |f| f[:accuracy_score] }
      total_contrarian = user_forecasts.sum { |f| f[:contrarian_bonus] }
      forecast_count = user_forecasts.size
      gameweeks = user_forecasts.map { |f| f[:gameweek_fpl_id] }.uniq.size

      {
        user_id: user_id,
        username: user.username,
        weighted_score: total_weighted_score.round(2),
        total_score: total_raw_score.round(2),
        accuracy_score: total_accuracy.round(2),
        contrarian_bonus: total_contrarian.round(2),
        forecast_count: forecast_count,
        average_score: (total_raw_score / forecast_count).round(2),
        gameweeks_participated: gameweeks
      }
    end

    # Sort by weighted score and add ranks
    user_scores.sort_by { |u| -u[:weighted_score] }.each_with_index.map do |ranking, index|
      ranking.merge(rank: index + 1)
    end
  end

  private

  def self.calculate_weighted_scores
    # Get the most recent gameweek to calculate recency weights
    latest_gameweek = Gameweek.joins("JOIN forecasts ON forecasts.gameweek_id = gameweeks.id")
                             .where.not(forecasts: { total_score: nil })
                             .maximum(:fpl_id) || 1

    # Get all forecasts with their gameweek fpl_id
    forecasts = Forecast.joins(:gameweek, :user)
                       .where.not(total_score: nil)
                       .select(
                         "forecasts.*",
                         "gameweeks.fpl_id as gameweek_fpl_id",
                         "users.email"
                       )

    # Calculate weighted scores
    forecasts.map do |forecast|
      weeks_ago = latest_gameweek - forecast.gameweek_fpl_id

      # Weight calculation: more recent weeks get higher weights
      # Week 0 (current): weight = 1.0
      # Week 1 back: weight = 0.9
      # Week 2 back: weight = 0.8
      # etc., with minimum weight of 0.1
      weight = [ 1.0 - (weeks_ago * 0.1), 0.1 ].max

      {
        user_id: forecast.user_id,
        gameweek_fpl_id: forecast.gameweek_fpl_id,
        total_score: forecast.total_score.to_f,
        accuracy_score: forecast.accuracy_score.to_f,
        contrarian_bonus: forecast.contrarian_bonus.to_f,
        weight: weight,
        weighted_score: forecast.total_score.to_f * weight
      }
    end
  end

  def self.weekly_performance(user_id, limit: 10)
    # Get weekly performance for a specific user (simplified for profile view)
    Forecast.joins(:gameweek, :user)
            .where(user_id: user_id)
            .where.not(total_score: nil)
            .group("gameweeks.id, gameweeks.fpl_id")
            .select(
              "gameweeks.fpl_id as week",
              "SUM(total_score) as total_score",
              "SUM(accuracy_score) as accuracy_score",
              "SUM(contrarian_bonus) as contrarian_bonus",
              "COUNT(*) as forecast_count",
              "AVG(total_score) as average_score"
            )
            .order("gameweeks.fpl_id DESC")
            .limit(limit)
            .map do |performance|
              {
                gameweek: performance.week,
                total_score: performance.total_score.to_f.round(2),
                accuracy_score: performance.accuracy_score.to_f.round(2),
                contrarian_bonus: performance.contrarian_bonus.to_f.round(2),
                forecast_count: performance.forecast_count,
                average_score: performance.average_score.to_f.round(2)
              }
            end
  end

  def self.weekly_forecasts(user_id, gameweek_number)
    # Get detailed forecasts for a specific user and gameweek
    gameweek = Gameweek.find_by(fpl_id: gameweek_number)
    return [] unless gameweek

    Forecast.joins(:player, player: :team)
           .joins(:gameweek)
           .where(user_id: user_id, gameweek: gameweek)
           .where.not(total_score: nil)
           .select(
             "forecasts.*",
             "players.first_name",
             "players.last_name",
             "players.position",
             "teams.name as team_name",
             "gameweeks.fpl_id as gameweek_fpl_id"
           )
           .order("total_score DESC")
           .map do |forecast|
             # Get the actual performance for comparison
             performance = Performance.find_by(player_id: forecast.player_id, gameweek_id: forecast.gameweek_id)

             {
               player_name: "#{forecast.first_name} #{forecast.last_name}",
               team_name: forecast.team_name,
               position: forecast.position,
               category: forecast.category,
               total_score: forecast.total_score.to_f.round(2),
               accuracy_score: forecast.accuracy_score.to_f.round(2),
               contrarian_bonus: forecast.contrarian_bonus.to_f.round(2),
               actual_points: performance&.gameweek_score || 0,
               gameweek: forecast.gameweek_fpl_id
             }
           end
  end
end
