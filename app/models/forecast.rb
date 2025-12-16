class Forecast < ApplicationRecord
  belongs_to :user
  belongs_to :player
  belongs_to :gameweek
  belongs_to :strategy, optional: true  # Only set for bot-generated forecasts

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

  # Position slot limit validation (only on create - allows updating legacy forecasts)
  validate :position_slot_limit, on: :create

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

    # Get gameweek fpl_id for legacy slot detection
    gameweek_record = gameweek.is_a?(Gameweek) ? gameweek : Gameweek.find(gameweek_id)
    gameweek_fpl_id = gameweek_record.fpl_id

    # Identify which forecasts should be scored (top X per position)
    scorable_bot_forecast_ids = scorable_bot_forecasts(forecasts, gameweek_fpl_id)
    scorable_human_forecast_ids = scorable_human_forecasts(forecasts, performances)
    scorable_forecast_ids = scorable_bot_forecast_ids + scorable_human_forecast_ids

    # Build a set of scorable forecasts for accuracy calculation
    scorable_forecasts = forecasts.select { |f| scorable_forecast_ids.include?(f.id) }

    # Process each forecast
    forecasts.each do |forecast|
      # Skip forecasts outside their top picks per position
      unless scorable_forecast_ids.include?(forecast.id)
        forecast.update!(accuracy: nil) if forecast.accuracy.present?
        next
      end

      performance = performances[forecast.player_id]
      next unless performance # Skip if no performance data

      # Calculate accuracy - only exclude user's OTHER scorable forecasts, not all forecasts
      accuracy = calculate_accuracy_score(forecast, scorable_forecasts, performances)

      forecast.update!(accuracy: accuracy)
    end
  end

  # Legacy slot config (GW15 and earlier)
  LEGACY_SLOTS = {
    "goalkeeper" => 5,
    "defender" => 10,
    "midfielder" => 10,
    "forward" => 5
  }.freeze

  # Returns IDs of bot forecasts that should be scored (top X per position based on rank)
  def self.scorable_bot_forecasts(forecasts, gameweek_fpl_id)
    bot_forecasts = forecasts.select { |f| f.user.bot? && f.rank.present? }

    scorable_ids = []
    FantasyForecast::POSITION_CONFIG.each do |position, config|
      # Use legacy slots for GW15 and earlier, current config for GW16+
      slots = if gameweek_fpl_id && gameweek_fpl_id <= 15
                LEGACY_SLOTS[position]
      else
                config[:slots]
      end

      position_forecasts = bot_forecasts
        .select { |f| f.player.position == position }
        .sort_by(&:rank)
        .first(slots)

      scorable_ids.concat(position_forecasts.map(&:id))
    end

    scorable_ids
  end

  # Returns IDs of human forecasts that should be scored
  # All human forecasts are scored (legacy data may have more than slot limits)
  def self.scorable_human_forecasts(forecasts, performances)
    forecasts.select { |f| !f.user.bot? }.map(&:id)
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
  # Bot forecasts are exempt - they create forecasts for all players to provide rankings
  def position_slot_limit
    return unless player&.position && user_id && gameweek_id
    return if user&.bot?  # Bots can create unlimited forecasts (for rankings)

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
