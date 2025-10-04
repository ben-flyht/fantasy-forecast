class Forecast < ApplicationRecord
  belongs_to :user
  belongs_to :player
  belongs_to :gameweek

  # Callbacks
  before_validation :assign_next_gameweek!

  # Uniqueness constraint: one forecast per user/player/gameweek
  validates :user_id, uniqueness: { scope: [ :player_id, :gameweek_id ] }

  # Position slot limit validation
  validate :position_slot_limit

  # Scopes
  scope :by_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :scored, -> { where.not(total_score: nil) }
  scope :by_total_score, -> { order(total_score: :desc) }

  # Map week to gameweek fpl_id
  scope :by_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }
  scope :for_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }

  # Class methods for consensus scoring
  def self.consensus_scores_for_week(week)
    joins(:gameweek, player: :team)
      .where(gameweeks: { fpl_id: week })
      .group("players.id, players.first_name, players.last_name, teams.name, players.position")
      .select("players.id as player_id, CONCAT(players.first_name, ' ', players.last_name) as name, players.first_name, players.last_name, teams.name as team, players.position, COUNT(*) as total_forecasts")
      .order("total_forecasts DESC")
  end

  # Class method for consensus scoring filtered by position
  def self.consensus_scores_for_week_by_position(week, position)
    joins(:gameweek, player: :team)
      .where(gameweeks: { fpl_id: week }, players: { position: position })
      .group("players.id, players.first_name, players.last_name, teams.name, players.position")
      .select("players.id as player_id, CONCAT(players.first_name, ' ', players.last_name) as name, players.first_name, players.last_name, teams.name as team, players.position, COUNT(*) as total_forecasts")
      .order("total_forecasts DESC")
  end


  # Class method for auto-assignment
  def self.assign_current_gameweek!
    current_gameweek = Gameweek.current_gameweek
    current_gameweek&.id
  end

  # Class method for assigning next gameweek
  def self.assign_next_gameweek!
    next_gameweek = Gameweek.next_gameweek
    next_gameweek&.id
  end

  # Calculate scores for all forecasts in a given gameweek
  def self.calculate_scores_for_gameweek!(gameweek)
    gameweek_id = gameweek.is_a?(Gameweek) ? gameweek.id : gameweek

    # Get all forecasts for this gameweek
    forecasts = includes(:player, :user).where(gameweek_id: gameweek_id)

    # Get performance data for this gameweek
    performances = Performance.includes(:player)
                             .where(gameweek_id: gameweek_id)
                             .index_by(&:player_id)

    # Calculate rankings by position for this gameweek
    position_rankings = calculate_position_rankings(performances)

    # Get forecast counts by player for differential scoring
    forecast_counts = forecasts.group(:player_id).count

    # Get total number of unique forecasters for percentage calculations
    total_forecasters = forecasts.distinct.count(:user_id)

    # Group forecasts by user to calculate availability
    forecasts_by_user = forecasts.group_by(&:user_id)

    # Calculate total required slots across all positions
    total_required_slots = FantasyForecast::POSITION_CONFIG.values.sum { |config| config[:slots] }

    # Calculate availability score for each user
    availability_by_user = {}
    forecasts_by_user.each do |user_id, user_forecasts|
      actual_slots = user_forecasts.count
      availability_score = actual_slots.to_f / total_required_slots
      availability_by_user[user_id] = availability_score
    end

    # Process each forecast
    forecasts.find_each do |forecast|
      performance = performances[forecast.player_id]
      next unless performance # Skip if no performance data

      accuracy_score = calculate_accuracy_score(forecast, performance, position_rankings)
      differential_score = calculate_differential_score(forecast, forecast_counts, total_forecasters)
      availability_score = availability_by_user[forecast.user_id]

      # Forecaster score = accuracy × differential × availability (0.0 to 1.0)
      forecaster_score = accuracy_score * differential_score * availability_score

      forecast.update!(
        accuracy_score: accuracy_score,
        differential_score: differential_score,
        total_score: forecaster_score
      )
    end
  end

  private

  # Calculate position-based rankings for the gameweek
  def self.calculate_position_rankings(performances)
    rankings = {}

    # Group by position and rank by gameweek_score
    performances.values.group_by { |p| p.player.position }.each do |position, position_performances|
      sorted_performances = position_performances.sort_by(&:gameweek_score).reverse

      sorted_performances.each_with_index do |performance, index|
        rankings[performance.player_id] = {
          position: position,
          rank: index + 1,
          total_in_position: sorted_performances.size,
          score: performance.gameweek_score
        }
      end
    end

    rankings
  end

  # Calculate accuracy score based on actual performance (0.0 to 1.0)
  # 1.0 = Player finished 1st in their position
  # 0.0 = Player finished last in their position
  def self.calculate_accuracy_score(forecast, performance, position_rankings)
    ranking = position_rankings[forecast.player_id]
    return 0.0 unless ranking

    position_total = ranking[:total_in_position]
    rank = ranking[:rank]

    # Return 0 if only one player in position (can't calculate)
    return 0.0 if position_total <= 1

    # Formula: (total_players - rank) / (total_players - 1)
    # Rank 1 of 30: (30 - 1) / 29 = 1.0
    # Rank 30 of 30: (30 - 30) / 29 = 0.0
    (position_total - rank).to_f / (position_total - 1)
  end

  # Calculate differential score for unique/unpopular picks (0.0 to 1.0)
  # 1.0 = Only you picked this player (unique)
  # 0.0 = Everyone picked this player (consensus)
  def self.calculate_differential_score(forecast, forecast_counts, total_forecasters)
    player_count = forecast_counts[forecast.player_id] || 0

    # Return 1.0 if you're the only forecaster (edge case)
    return 1.0 if total_forecasters <= 1

    # Count other forecasters who picked this player (excluding yourself)
    other_forecasters_who_picked = player_count - 1
    total_other_forecasters = total_forecasters - 1

    # Formula: 1.0 - (other_forecasters_who_picked / total_other_forecasters)
    # 0 others picked: 1.0 - (0 / 19) = 1.0
    # All others picked: 1.0 - (19 / 19) = 0.0
    1.0 - (other_forecasters_who_picked.to_f / total_other_forecasters)
  end

  private

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
