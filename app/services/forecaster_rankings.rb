class ForecasterRankings
  def self.for_gameweek(gameweek)
    # Get rankings for a specific gameweek
    gameweek_record = Gameweek.find_by(fpl_id: gameweek)
    return [] unless gameweek_record

    # Get all users who have ever made forecasts
    all_forecasters = User.joins(:forecasts)
                         .where.not(forecasts: { accuracy: nil })
                         .distinct
                         .select(:id, :username)

    # Get scores for this specific gameweek
    gameweek_scores = Forecast.joins(:user)
                           .where(gameweek: gameweek_record)
                           .where.not(accuracy: nil)
                           .select("forecasts.*", "users.username")
                           .group_by(&:user_id)

    # Calculate total required slots across all positions
    total_required_slots = FantasyForecast::POSITION_CONFIG.values.sum { |config| config[:slots] }

    # Calculate scores for all forecasters
    user_scores = all_forecasters.map do |user|
      user_score_records = gameweek_scores[user.id] || []

      if user_score_records.any?
        avg_score = user_score_records.sum { |s| s.total_score.to_f } / user_score_records.size
        avg_accuracy = user_score_records.sum { |s| s.accuracy.to_f } / user_score_records.size
        forecast_count = user_score_records.size
      else
        # User didn't forecast this gameweek - give them 0 scores
        avg_score = 0.0
        avg_accuracy = 0.0
        forecast_count = 0
      end

      # Calculate availability (forecasts made / total required)
      availability_score = forecast_count.to_f / total_required_slots

      {
        user_id: user.id,
        username: user.username,
        total_score: avg_score.round(4),
        accuracy_score: avg_accuracy.round(4),
        availability_score: availability_score.round(4),
        forecast_count: forecast_count
      }
    end

    # Sort by total_score, then accuracy_score
    user_scores.sort_by { |u| [ -u[:total_score], -u[:accuracy_score] ] }.each_with_index.map do |ranking, index|
      ranking.merge(rank: index + 1)
    end
  end

  def self.overall
    # Get all gameweeks that have scores (from starting gameweek onwards)
    starting_gameweek = Gameweek::STARTING_GAMEWEEK
    gameweeks_with_scores = Forecast.joins(:gameweek)
                                  .where.not(accuracy: nil)
                                  .where("gameweeks.fpl_id >= ?", starting_gameweek)
                                  .distinct
                                  .pluck("gameweeks.fpl_id")

    total_gameweeks = gameweeks_with_scores.size

    # If no scored gameweeks yet, show all forecasters with 0 scores and rank 1=
    if total_gameweeks == 0
      all_forecasters = User.joins(:forecasts)
                           .distinct
                           .select(:id, :username)
                           .order(:username)

      return all_forecasters.map do |user|
        {
          user_id: user.id,
          username: user.username,
          total_score: 0.0,
          accuracy_score: 0.0,
          availability_score: 0.0,
          forecast_count: 0,
          gameweeks_participated: 0,
          rank: "1="
        }
      end
    end

    # Calculate total required slots across all positions
    total_required_slots = FantasyForecast::POSITION_CONFIG.values.sum { |config| config[:slots] }
    total_possible_forecasts = total_required_slots * total_gameweeks

    # Get all users who have scores
    all_forecasters = User.joins(:forecasts)
                         .joins("JOIN gameweeks ON forecasts.gameweek_id = gameweeks.id")
                         .where.not(forecasts: { accuracy: nil })
                         .where("gameweeks.fpl_id >= ?", starting_gameweek)
                         .distinct
                         .select(:id, :username)

    # Get all scores with their gameweek data (from starting gameweek onwards)
    all_scores = Forecast.joins(:gameweek, :user)
                      .where.not(accuracy: nil)
                      .where("gameweeks.fpl_id >= ?", starting_gameweek)
                      .select("forecasts.*", "gameweeks.fpl_id as gameweek_fpl_id", "users.username")
                      .group_by(&:user_id)

    # Calculate scores for all forecasters
    user_scores = all_forecasters.map do |user|
      user_scores_by_gw = (all_scores[user.id] || []).group_by(&:gameweek_fpl_id)

      # Calculate average across gameweeks participated
      total_score_sum = 0.0
      accuracy_sum = 0.0
      gameweeks_participated = 0
      total_forecasts_made = 0

      gameweeks_with_scores.each do |gw_fpl_id|
        gameweek_forecasts = user_scores_by_gw[gw_fpl_id]
        if gameweek_forecasts&.any?
          # Average accuracy and total_score across all forecasts in this gameweek
          avg_gw_accuracy = gameweek_forecasts.sum { |f| f.accuracy.to_f } / gameweek_forecasts.size
          avg_gw_total_score = gameweek_forecasts.sum { |f| f.total_score.to_f } / gameweek_forecasts.size

          total_score_sum += avg_gw_total_score
          accuracy_sum += avg_gw_accuracy
          gameweeks_participated += 1
          total_forecasts_made += gameweek_forecasts.size
        end
      end

      # Average across gameweeks participated (not all gameweeks)
      avg_score = gameweeks_participated > 0 ? total_score_sum / gameweeks_participated : 0.0
      avg_accuracy = gameweeks_participated > 0 ? accuracy_sum / gameweeks_participated : 0.0

      # Calculate availability (gameweeks participated / total gameweeks)
      availability_score = gameweeks_participated.to_f / total_gameweeks

      {
        user_id: user.id,
        username: user.username,
        total_score: avg_score.round(4),
        accuracy_score: avg_accuracy.round(4),
        availability_score: availability_score.round(4),
        forecast_count: total_forecasts_made,
        gameweeks_participated: gameweeks_participated
      }
    end

    # Sort by total_score, then accuracy_score
    user_scores.sort_by { |u| [ -u[:total_score], -u[:accuracy_score] ] }.each_with_index.map do |ranking, index|
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

  def self.weekly_performance(user_id, limit: nil)
    # Get weekly performance for a specific user (from starting gameweek onwards)
    # Calculate total required slots across all positions
    total_required_slots = FantasyForecast::POSITION_CONFIG.values.sum { |config| config[:slots] }
    starting_gameweek = Gameweek::STARTING_GAMEWEEK

    # Get all gameweeks this user has forecasts for
    gameweeks_with_forecasts = Forecast.joins(:gameweek)
                                      .where(user_id: user_id)
                                      .where("gameweeks.fpl_id >= ?", starting_gameweek)
                                      .group("gameweeks.fpl_id")
                                      .pluck("gameweeks.fpl_id")
                                      .sort
                                      .reverse

    gameweeks_with_forecasts = gameweeks_with_forecasts.first(limit) if limit

    gameweeks_with_forecasts.map do |gw_fpl_id|
      # Get all forecasts for this gameweek
      all_forecasts = Forecast.where(user_id: user_id)
                              .joins(:gameweek)
                              .where("gameweeks.fpl_id = ?", gw_fpl_id)

      # Get scored forecasts for accuracy calculation
      scored_forecasts = all_forecasts.where.not(accuracy: nil)

      # Calculate availability from ALL forecasts, accuracy from SCORED forecasts
      forecast_count = all_forecasts.count
      avg_accuracy = scored_forecasts.any? ? scored_forecasts.average(:accuracy).to_f : 0.0
      availability_score = forecast_count.to_f / total_required_slots
      total_score = avg_accuracy * availability_score

      {
        gameweek: gw_fpl_id,
        total_score: total_score.round(4),
        accuracy_score: avg_accuracy.round(4),
        availability_score: availability_score.round(4),
        forecast_count: forecast_count
      }
    end
  end

  def self.weekly_forecasts(user_id, gameweek_number)
    # Get detailed forecasts for a specific user and gameweek with scores
    gameweek = Gameweek.find_by(fpl_id: gameweek_number)
    return [] unless gameweek

    # Get forecasts with player data (including unscored forecasts for next gameweek)
    Forecast.includes(player: :team)
           .where(user_id: user_id, gameweek: gameweek)
           .order("accuracy DESC NULLS LAST")
  end
end
