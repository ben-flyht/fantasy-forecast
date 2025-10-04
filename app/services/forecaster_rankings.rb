class ForecasterRankings
  def self.for_gameweek(gameweek)
    # Get rankings for a specific gameweek
    gameweek_record = Gameweek.find_by(fpl_id: gameweek)
    return [] unless gameweek_record

    # Get all users who have ever made forecasts
    all_forecasters = User.joins(:forecasts)
                         .where.not(forecasts: { total_score: nil })
                         .distinct
                         .select(:id, :username)

    # Get forecasts for this specific gameweek with scores
    gameweek_forecasts = Forecast.joins(:user)
                                 .where(gameweek: gameweek_record)
                                 .where.not(total_score: nil)
                                 .select("forecasts.*", "users.username")
                                 .group_by(&:user_id)

    # Calculate total required slots across all positions
    total_required_slots = FantasyForecast::POSITION_CONFIG.values.sum { |config| config[:slots] }

    # Calculate scores for all forecasters
    user_scores = all_forecasters.map do |user|
      user_forecasts = gameweek_forecasts[user.id] || []

      if user_forecasts.any?
        avg_score = user_forecasts.sum { |f| f.total_score.to_f } / user_forecasts.size
        avg_accuracy = user_forecasts.sum { |f| f.accuracy_score.to_f } / user_forecasts.size
        avg_differential = user_forecasts.sum { |f| f.differential_score.to_f } / user_forecasts.size
        forecast_count = user_forecasts.size
      else
        # User didn't forecast this gameweek - give them 0 scores
        avg_score = 0.0
        avg_accuracy = 0.0
        avg_differential = 0.0
        forecast_count = 0
      end

      # Calculate availability (forecasts made / total required)
      availability_score = forecast_count.to_f / total_required_slots

      {
        user_id: user.id,
        username: user.username,
        total_score: avg_score.round(4),
        accuracy_score: avg_accuracy.round(4),
        differential_score: avg_differential.round(4),
        availability_score: availability_score.round(4),
        forecast_count: forecast_count
      }
    end

    # Sort by total_score, then accuracy_score, then differential_score
    user_scores.sort_by { |u| [ -u[:total_score], -u[:accuracy_score], -u[:differential_score] ] }.each_with_index.map do |ranking, index|
      ranking.merge(rank: index + 1)
    end
  end

  def self.overall
    # Get all gameweeks that have scored forecasts
    gameweeks_with_forecasts = Forecast.joins(:gameweek)
                                       .where.not(total_score: nil)
                                       .distinct
                                       .pluck("gameweeks.fpl_id")

    total_gameweeks = gameweeks_with_forecasts.size
    return [] if total_gameweeks == 0

    # Calculate total required slots across all positions
    total_required_slots = FantasyForecast::POSITION_CONFIG.values.sum { |config| config[:slots] }
    total_possible_forecasts = total_required_slots * total_gameweeks

    # Get all users who have made any forecasts
    all_forecasters = User.joins(:forecasts)
                         .where.not(forecasts: { total_score: nil })
                         .distinct
                         .select(:id, :username)

    # Get all forecasts with their gameweek data
    all_forecasts = Forecast.joins(:gameweek, :user)
                           .where.not(total_score: nil)
                           .select("forecasts.*", "gameweeks.fpl_id as gameweek_fpl_id", "users.username")
                           .group_by(&:user_id)

    # Calculate scores for all forecasters
    user_scores = all_forecasters.map do |user|
      user_forecasts_by_gw = (all_forecasts[user.id] || []).index_by(&:gameweek_fpl_id)

      # Calculate average across ALL gameweeks (0 if didn't participate)
      total_score_sum = 0.0
      accuracy_sum = 0.0
      differential_sum = 0.0
      total_forecast_count = 0

      gameweeks_with_forecasts.each do |gw_fpl_id|
        forecast = user_forecasts_by_gw[gw_fpl_id]
        if forecast
          total_score_sum += forecast.total_score.to_f
          accuracy_sum += forecast.accuracy_score.to_f
          differential_sum += forecast.differential_score.to_f
          total_forecast_count += 1
        end
        # If no forecast, adds 0 (implicit)
      end

      avg_score = total_score_sum / total_gameweeks
      avg_accuracy = accuracy_sum / total_gameweeks
      avg_differential = differential_sum / total_gameweeks

      # Calculate availability (total forecasts made / total possible forecasts)
      availability_score = total_forecast_count.to_f / total_possible_forecasts

      {
        user_id: user.id,
        username: user.username,
        total_score: avg_score.round(4),
        accuracy_score: avg_accuracy.round(4),
        differential_score: avg_differential.round(4),
        availability_score: availability_score.round(4),
        forecast_count: total_forecast_count,
        gameweeks_participated: total_forecast_count
      }
    end

    # Sort by total_score, then accuracy_score, then differential_score
    user_scores.sort_by { |u| [ -u[:total_score], -u[:accuracy_score], -u[:differential_score] ] }.each_with_index.map do |ranking, index|
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
        differential_score: forecast.differential_score.to_f,
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
              "AVG(total_score) as total_score",
              "AVG(accuracy_score) as accuracy_score",
              "AVG(differential_score) as differential_score",
              "COUNT(*) as forecast_count"
            )
            .order("gameweeks.fpl_id DESC")
            .limit(limit)
            .map do |performance|
              {
                gameweek: performance.week,
                total_score: performance.total_score.to_f.round(4),
                accuracy_score: performance.accuracy_score.to_f.round(4),
                differential_score: performance.differential_score.to_f.round(4),
                forecast_count: performance.forecast_count
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
               forecaster_score: forecast.total_score.to_f.round(4),
               accuracy_score: forecast.accuracy_score.to_f.round(4),
               differential_score: forecast.differential_score.to_f.round(4),
               actual_points: performance&.gameweek_score || 0,
               gameweek: forecast.gameweek_fpl_id
             }
           end
  end
end
