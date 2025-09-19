class PredictionAggregator
  def self.for_week(week)
    aggregate_predictions(Prediction.for_week(week))
  end

  def self.for_rest_of_season
    aggregate_predictions(Prediction.where(season_type: "rest_of_season"))
  end

  def self.for_player(player_id)
    aggregate_predictions(Prediction.for_player(player_id))
  end

  def self.for_user(user_id)
    aggregate_predictions(Prediction.for_user(user_id))
  end

  def self.consensus_summary_for_week(week)
    result = {}
    Prediction.consensus_for_week(week).each do |prediction|
      result[prediction.player_id] ||= {}
      # prediction.category is already a string from the SQL select
      category_name = prediction.category.to_s
      result[prediction.player_id][category_name] = prediction.count.to_i
    end
    result
  end

  def self.consensus_summary_rest_of_season
    result = {}
    Prediction.consensus_rest_of_season.each do |prediction|
      result[prediction.player_id] ||= {}
      # prediction.category is already a string from the SQL select
      category_name = prediction.category.to_s
      result[prediction.player_id][category_name] = prediction.count.to_i
    end
    result
  end

  # Enhanced methods for consensus feature with Player objects
  def self.weekly_consensus(week)
    consensus_data = consensus_summary_for_week(week)
    build_consensus_with_players(consensus_data)
  end

  def self.rest_of_season_consensus
    consensus_data = consensus_summary_rest_of_season
    build_consensus_with_players(consensus_data)
  end

  # Get top N players for a specific category and week
  def self.top_for_week(week, category, limit = 10)
    consensus_data = weekly_consensus(week)
    get_top_players_by_category(consensus_data, category, limit)
  end

  # Get top N players for a specific category (rest of season)
  def self.top_rest_of_season(category, limit = 10)
    consensus_data = rest_of_season_consensus
    get_top_players_by_category(consensus_data, category, limit)
  end

  # Get all consensus data organized by category for weekly
  def self.weekly_consensus_by_category(week)
    consensus_data = weekly_consensus(week)
    organize_by_category(consensus_data)
  end

  # Get all consensus data organized by category for rest of season
  def self.rest_of_season_consensus_by_category
    consensus_data = rest_of_season_consensus
    organize_by_category(consensus_data)
  end

  private

  def self.aggregate_predictions(predictions)
    result = {}

    predictions.group(:player_id, :category).count.each do |(player_id, category), count|
      result[player_id] ||= {
        "must_have" => 0,
        "better_than_expected" => 0,
        "worse_than_expected" => 0
      }

      # category is an integer from enum, convert to string name
      category_name = if category.is_a?(Integer)
        Prediction.categories.key(category).to_s
      else
        category.to_s
      end

      result[player_id][category_name] = count
    end

    result
  end

  # Build consensus data with Player objects for easier view rendering
  def self.build_consensus_with_players(consensus_data)
    return {} if consensus_data.empty?

    player_ids = consensus_data.keys
    players = Player.where(id: player_ids).index_by(&:id)

    result = {}
    consensus_data.each do |player_id, categories|
      player = players[player_id]
      next unless player

      result[player_id] = {
        player: player,
        votes: categories,
        total_votes: categories.values.sum
      }
    end

    result
  end

  # Get top N players for a specific category, sorted by vote count
  def self.get_top_players_by_category(consensus_data, category, limit)
    # Filter players who have votes in this category and sort by vote count
    players_with_votes = consensus_data.select do |_player_id, data|
      data[:votes][category.to_s].to_i > 0
    end

    # Sort by vote count for this category (descending) and limit results
    sorted_players = players_with_votes.sort_by do |_player_id, data|
      -data[:votes][category.to_s].to_i
    end

    sorted_players.first(limit).map do |player_id, data|
      {
        player: data[:player],
        votes: data[:votes][category.to_s].to_i,
        total_votes: data[:total_votes]
      }
    end
  end

  # Organize consensus data by category for easier view rendering
  def self.organize_by_category(consensus_data)
    categories = %w[must_have better_than_expected worse_than_expected]
    result = {}

    categories.each do |category|
      result[category] = get_top_players_by_category(consensus_data, category, 100)
    end

    result
  end
end
