class ForecasterRankings
  def self.for_gameweek(gameweek)
    # Get rankings for a specific gameweek
    gameweek_record = Gameweek.find_by(fpl_id: gameweek)
    return [] unless gameweek_record

    # Get all users who have ever made forecasts
    all_forecasters = User.joins(:forecasts)
                         .where.not(forecasts: { accuracy: nil })
                         .distinct
                         .select(:id, :username, :bot)

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
        avg_accuracy = user_score_records.sum { |s| s.accuracy.to_f } / user_score_records.size
        forecast_count = user_score_records.size
      else
        # User didn't forecast this gameweek - give them 0 scores
        avg_accuracy = 0.0
        forecast_count = 0
      end

      # Score = average accuracy * forecast count
      total_score = avg_accuracy * forecast_count

      {
        user_id: user.id,
        username: user.display_name,
        total_score: total_score.round(4),
        accuracy_score: avg_accuracy.round(4),
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
                           .select(:id, :username, :bot)
                           .order(:username)

      return all_forecasters.map do |user|
        {
          user_id: user.id,
          username: user.display_name,
          is_bot: user.bot?,
          total_score: 0.0,
          accuracy_score: 0.0,
          forecast_count: 0,
          gameweeks_participated: 0,
          beats_bot: false,
          rank: "1="
        }
      end
    end

    # Get all users who have scores
    all_forecasters = User.joins(:forecasts)
                         .joins("JOIN gameweeks ON forecasts.gameweek_id = gameweeks.id")
                         .where.not(forecasts: { accuracy: nil })
                         .where("gameweeks.fpl_id >= ?", starting_gameweek)
                         .distinct
                         .select(:id, :username, :bot)

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
      accuracy_sum = 0.0
      gameweeks_participated = 0
      total_forecasts_made = 0

      gameweeks_with_scores.each do |gw_fpl_id|
        gameweek_forecasts = user_scores_by_gw[gw_fpl_id]
        if gameweek_forecasts&.any?
          # Average accuracy across all forecasts in this gameweek
          avg_gw_accuracy = gameweek_forecasts.sum { |f| f.accuracy.to_f } / gameweek_forecasts.size

          accuracy_sum += avg_gw_accuracy
          gameweeks_participated += 1
          total_forecasts_made += gameweek_forecasts.size
        end
      end

      # Average accuracy across gameweeks participated
      avg_accuracy = gameweeks_participated > 0 ? accuracy_sum / gameweeks_participated : 0.0

      # Score = average accuracy * forecast count
      total_score = avg_accuracy * total_forecasts_made

      {
        user_id: user.id,
        username: user.display_name,
        is_bot: user.bot?,
        total_score: total_score.round(4),
        accuracy_score: avg_accuracy.round(4),
        forecast_count: total_forecasts_made,
        gameweeks_participated: gameweeks_participated
      }
    end

    # Sort by total_score, then accuracy_score
    ranked_scores = user_scores.sort_by { |u| [ -u[:total_score], -u[:accuracy_score] ] }.each_with_index.map do |ranking, index|
      ranking.merge(rank: index + 1)
    end

    # Find bot accuracy and mark humans who beat it
    bot_accuracy = ranked_scores.find { |r| r[:is_bot] }&.dig(:accuracy_score) || 0.0

    ranked_scores.map do |ranking|
      ranking.merge(beats_bot: !ranking[:is_bot] && ranking[:accuracy_score] > bot_accuracy)
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
      # Get scored forecasts only (bot has many unscored forecasts for rankings)
      scored_forecasts = Forecast.where(user_id: user_id)
                                 .joins(:gameweek)
                                 .where("gameweeks.fpl_id = ?", gw_fpl_id)
                                 .where.not(accuracy: nil)

      forecast_count = scored_forecasts.count
      avg_accuracy = scored_forecasts.any? ? scored_forecasts.average(:accuracy).to_f : 0.0
      total_score = avg_accuracy * forecast_count

      {
        gameweek: gw_fpl_id,
        total_score: total_score.round(4),
        accuracy_score: avg_accuracy.round(4),
        forecast_count: forecast_count
      }
    end
  end

  def self.weekly_forecasts(user_id, gameweek_number)
    # Get detailed forecasts for a specific user and gameweek with scores
    gameweek = Gameweek.find_by(fpl_id: gameweek_number)
    return [] unless gameweek

    user = User.find(user_id)
    forecasts = Forecast.includes(player: :team).where(user_id: user_id, gameweek: gameweek)

    # For bots, only show scored forecasts (they have many unscored for rankings)
    # For humans, show all forecasts (including unscored for next gameweek)
    forecasts = forecasts.where.not(accuracy: nil) if user.bot? && gameweek.is_finished?

    forecasts.order("accuracy DESC NULLS LAST")
  end
end
