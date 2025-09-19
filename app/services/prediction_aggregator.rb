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
end
