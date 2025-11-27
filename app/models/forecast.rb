class Forecast < ApplicationRecord
  belongs_to :user
  belongs_to :player
  belongs_to :gameweek

  # Callbacks
  before_validation :assign_next_gameweek!

  # Calculate total score on the fly: accuracy × availability
  def total_score
    return nil unless accuracy
    accuracy * availability_score
  end

  # Calculate availability for this user in this gameweek
  def availability_score
    total_required_slots = FantasyForecast::POSITION_CONFIG.values.sum { |config| config[:slots] }
    forecast_count = Forecast.where(user: user, gameweek: gameweek).count
    forecast_count.to_f / total_required_slots
  end

  # Uniqueness constraint: one forecast per user/player/gameweek
  validates :user_id, uniqueness: { scope: [ :player_id, :gameweek_id ] }

  # Position slot limit validation
  validate :position_slot_limit

  # Scopes
  scope :by_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :scored, -> { where.not(accuracy: nil) }
  scope :by_total_score, -> { order(accuracy: :desc) }

  # Map week to gameweek fpl_id
  scope :by_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }

  # Calculate scores for all forecasts in a given gameweek
  def self.calculate_scores_for_gameweek!(gameweek)
    gameweek_id = gameweek.is_a?(Gameweek) ? gameweek.id : gameweek

    # Get all forecasts for this gameweek (load into memory for efficiency)
    forecasts = includes(:player, :user).where(gameweek_id: gameweek_id).to_a

    # Get performance data for this gameweek
    performances = Performance.includes(:player)
                             .where(gameweek_id: gameweek_id)
                             .index_by(&:player_id)

    # Process each forecast
    forecasts.each do |forecast|
      performance = performances[forecast.player_id]
      next unless performance # Skip if no performance data

      # Calculate accuracy by comparing against other users' forecasts in same position
      accuracy = calculate_accuracy_score(forecast, forecasts, performances)

      forecast.update!(accuracy: accuracy)
    end
  end

  private

  # Calculate accuracy score based on actual performance compared to all players in position (0.0 to 1.0)
  # Formula: (total_unique_scores - rank) / (total_unique_scores - 1)
  # This ensures:
  #   Rank 1 of 13 unique scores: (13 - 1) / (13 - 1) = 100%
  #   Rank 7 of 13 unique scores: (13 - 7) / (13 - 1) = 50%
  #   Rank 13 of 13 unique scores: (13 - 13) / (13 - 1) = 0%
  # Players are ranked by unique score tiers among all performances,
  # but excluding this user's other forecasted players in the same position
  def self.calculate_accuracy_score(forecast, all_forecasts, performances)
    current_performance = performances[forecast.player_id]
    return 0.0 unless current_performance

    current_score = current_performance.gameweek_score
    current_position = forecast.player.position

    # Get player IDs that this user forecasted in the same position (excluding current player)
    user_forecasted_player_ids = all_forecasts
      .select { |f| f.user_id == forecast.user_id && f.player.position == current_position && f.player_id != forecast.player_id }
      .map(&:player_id)

    # Get all performances in this position, excluding the user's other forecasted players
    position_performances = performances.values.select do |perf|
      perf.player.position == current_position && !user_forecasted_player_ids.include?(perf.player_id)
    end

    # Get all scores for ranking
    scores = position_performances.map(&:gameweek_score)

    # If only one score, can't calculate accuracy
    return 0.0 if scores.size <= 1

    # Get unique scores and rank them from best to worst
    unique_scores = scores.uniq.sort.reverse
    total_unique_scores = unique_scores.size

    # Return 0 if only one unique score
    return 0.0 if total_unique_scores <= 1

    # Find rank of current score (1-indexed)
    rank = unique_scores.index(current_score) + 1

    # Calculate accuracy: (total - rank) / (total - 1)
    (total_unique_scores - rank).to_f / (total_unique_scores - 1)
  end

  # Validate position slot limits based on POSITION_CONFIG
  def position_slot_limit
    return unless player&.position && user_id && gameweek_id

    position_config = FantasyForecast::POSITION_CONFIG[player.position]
    return unless position_config

    max_slots = position_config[:slots]

    # Count existing forecasts for this user/gameweek/position
    existing_count = Forecast.joins(:player)
                           .where(user: user, gameweek: gameweek, players: { position: player.position })
                           .where.not(id: id) # Exclude current record for updates
                           .count

    if existing_count >= max_slots
      position_display = position_config[:display_name]
      errors.add(:player, "Too many picks for #{position_display}. Maximum #{max_slots} allowed.")
    end
  end

  # Instance method for auto-assignment
  def assign_next_gameweek!
    return if gameweek.present?  # Don't override if gameweek is already set

    next_gameweek = Gameweek.next_gameweek
    if next_gameweek
      self.gameweek = next_gameweek
    else
      errors.add(:gameweek, "No next gameweek available")
    end
  end
end
