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
  scope :by_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }

  # Legacy slot config (GW15 and earlier)
  LEGACY_SLOTS = { "goalkeeper" => 5, "defender" => 10, "midfielder" => 10, "forward" => 5 }.freeze

  # Calculate scores for all forecasts in a given gameweek
  def self.calculate_scores_for_gameweek!(gameweek)
    ForecastScoreCalculator.call(gameweek)
  end

  # Returns IDs of bot forecasts that should be scored (top X per position based on rank)
  def self.scorable_bot_forecasts(forecasts, gameweek_fpl_id)
    bot_forecasts = forecasts.select { |f| f.user.bot? && f.rank.present? }
    scorable_ids_for_positions(bot_forecasts, gameweek_fpl_id)
  end

  # Returns IDs of human forecasts that should be scored
  def self.scorable_human_forecasts(forecasts, _performances)
    forecasts.reject { |f| f.user.bot? }.map(&:id)
  end

  def self.scorable_ids_for_positions(bot_forecasts, gameweek_fpl_id)
    FantasyForecast::POSITION_CONFIG.flat_map do |position, config|
      slots = slots_for_position(position, config, gameweek_fpl_id)
      bot_forecasts.select { |f| f.player.position == position }.sort_by(&:rank).first(slots).map(&:id)
    end
  end

  def self.slots_for_position(position, config, gameweek_fpl_id)
    gameweek_fpl_id && gameweek_fpl_id <= 15 ? LEGACY_SLOTS[position] : config[:slots]
  end

  private

  def position_slot_limit
    return unless player&.position && user_id && gameweek_id
    return if user&.bot?

    max_slots = position_max_slots
    return unless max_slots && existing_position_count >= max_slots

    errors.add(:player, "Too many picks for #{position_display_name}. Maximum #{max_slots} allowed.")
  end

  def position_max_slots
    FantasyForecast::POSITION_CONFIG.dig(player.position, :slots)
  end

  def position_display_name
    FantasyForecast::POSITION_CONFIG.dig(player.position, :display_name)
  end

  def existing_position_count
    Forecast.joins(:player)
            .where(user: user, gameweek: gameweek, players: { position: player.position })
            .where.not(id: id)
            .count
  end

  def assign_next_gameweek!
    return if gameweek.present?

    next_gameweek = Gameweek.next_gameweek
    if next_gameweek
      self.gameweek = next_gameweek
    else
      errors.add(:gameweek, "No next gameweek available")
    end
  end
end
