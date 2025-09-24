class Forecast < ApplicationRecord
  belongs_to :user
  belongs_to :player
  belongs_to :gameweek

  CATEGORY_TARGET = "target".freeze
  CATEGORY_AVOID = "avoid".freeze

  enum :category, {
    target: CATEGORY_TARGET,
    avoid: CATEGORY_AVOID
  }

  # Callbacks
  before_validation :assign_next_gameweek!

  # Validations
  validates :category, presence: true

  # Uniqueness constraint: one forecast per user/player/gameweek
  validates :user_id, uniqueness: { scope: [ :player_id, :gameweek_id ] }

  # Position slot limit validation
  validate :position_slot_limit

  # Scopes
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :scored, -> { where.not(total_score: nil) }
  scope :by_total_score, -> { order(total_score: :desc) }

  # Map week to gameweek fpl_id
  scope :by_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }
  scope :for_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }

  # Class methods for consensus scoring (+1 for target, -1 for avoid)
  def self.consensus_scores_for_week(week)
    joins(:gameweek, player: :team)
      .where(gameweeks: { fpl_id: week })
      .group("players.id, players.first_name, players.last_name, teams.name, players.position")
      .select("players.id as player_id, CONCAT(players.first_name, ' ', players.last_name) as name, players.first_name, players.last_name, teams.name as team, players.position, SUM(CASE WHEN category = 'target' THEN 1 WHEN category = 'avoid' THEN -1 ELSE 0 END) as consensus_score, COUNT(*) as total_forecasts")
      .order("consensus_score DESC, total_forecasts DESC")
  end

  # Method for getting raw consensus data by category for aggregator
  def self.consensus_for_week(week)
    joins(:gameweek)
      .where(gameweeks: { fpl_id: week })
      .group(:player_id, :category)
      .select("player_id, category, COUNT(*) as count")
  end

  # Class method for consensus scoring filtered by position
  def self.consensus_scores_for_week_by_position(week, position)
    joins(:gameweek, player: :team)
      .where(gameweeks: { fpl_id: week }, players: { position: position })
      .group("players.id, players.first_name, players.last_name, teams.name, players.position")
      .select("players.id as player_id, CONCAT(players.first_name, ' ', players.last_name) as name, players.first_name, players.last_name, teams.name as team, players.position, SUM(CASE WHEN category = 'target' THEN 1 WHEN category = 'avoid' THEN -1 ELSE 0 END) as consensus_score, COUNT(*) as total_forecasts")
      .order("consensus_score DESC, total_forecasts DESC")
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

    # Get forecast counts by player for contrarian scoring
    forecast_counts = forecasts.group(:player_id, :category).count

    # Get total number of unique forecasters for percentage calculations
    total_forecasters = forecasts.distinct.count(:user_id)

    # Process each forecast
    forecasts.find_each do |forecast|
      performance = performances[forecast.player_id]
      next unless performance # Skip if no performance data

      accuracy_score = calculate_accuracy_score(forecast, performance, position_rankings)
      contrarian_bonus = calculate_contrarian_bonus(forecast, forecast_counts, total_forecasters)

      forecast.update!(
        accuracy_score: accuracy_score,
        contrarian_bonus: contrarian_bonus,
        total_score: accuracy_score + contrarian_bonus
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

  # Calculate accuracy score based on actual performance
  def self.calculate_accuracy_score(forecast, performance, position_rankings)
    ranking = position_rankings[forecast.player_id]
    return 0.0 unless ranking

    position_total = ranking[:total_in_position]
    rank = ranking[:rank]
    score = ranking[:score]

    if forecast.target?
      # For targets: reward high-performing players
      # Higher score = better rank (lower rank number)
      # Formula: ((total_players - rank + 1) / total_players) * max_score_factor * score
      rank_score = ((position_total - rank + 1).to_f / position_total) * 10
      performance_factor = score > 0 ? (1 + Math.log10(score + 1)) : 0.5
      rank_score * performance_factor
    else
      # For avoid: reward players who scored poorly AND were highly targeted
      target_forecasts = Forecast.where(
        gameweek_id: forecast.gameweek_id,
        player_id: forecast.player_id,
        category: "target"
      ).count

      # Score based on how poorly they performed vs how many people targeted them
      poor_performance_score = (rank.to_f / position_total) * 10 # Higher rank = worse performance = higher score
      target_popularity = target_forecasts > 0 ? (1 + Math.log10(target_forecasts + 1)) : 0.5

      poor_performance_score * target_popularity
    end
  end

  # Calculate contrarian bonus for unique/unpopular picks
  def self.calculate_contrarian_bonus(forecast, forecast_counts, total_forecasters)
    same_category_count = forecast_counts[[ forecast.player_id, forecast.category ]] || 0
    target_count = forecast_counts[[ forecast.player_id, "target" ]] || 0

    if forecast.target?
      # Reward picking players that few others picked (percentage-based)
      pick_percentage = same_category_count.to_f / total_forecasters

      if pick_percentage <= 0.05 # Less than 5% picked this player
        5.0 # Big bonus for very contrarian pick
      elsif pick_percentage <= 0.15 # Less than 15% picked this player
        3.0 # Good bonus for contrarian pick
      elsif pick_percentage <= 0.30 # Less than 30% picked this player
        1.0 # Small bonus for moderately unpopular pick
      else
        0.0 # No bonus for popular picks (>30%)
      end
    else
      # For avoid picks, bonus is based on percentage of people who wrongly targeted this player
      target_percentage = target_count.to_f / total_forecasters

      if target_percentage >= 0.30 # 30%+ of forecasters targeted this player
        4.0 # Excellent bonus for avoiding a very popular pick
      elsif target_percentage >= 0.15 # 15%+ of forecasters targeted this player
        2.5 # Good bonus for avoiding a popular pick
      elsif target_percentage >= 0.05 # 5%+ of forecasters targeted this player
        1.0 # Decent bonus for avoiding a moderately targeted pick
      else
        0.2 # Small bonus for any avoid pick
      end
    end
  end

  private

  # Validate position slot limits based on POSITION_CONFIG
  def position_slot_limit
    return unless player&.position && user_id && gameweek_id

    position_config = FantasyForecast::POSITION_CONFIG[player.position]
    return unless position_config

    max_slots = position_config[:slots]

    # Count existing forecasts for this user/gameweek/position/category
    existing_count = Forecast.joins(:player)
                           .where(user: user, gameweek: gameweek, category: category, players: { position: player.position })
                           .where.not(id: id) # Exclude current record for updates
                           .count

    if existing_count >= max_slots
      position_display = position_config[:display_name]
      errors.add(:player, "Too many #{category} picks for #{position_display}. Maximum #{max_slots} allowed.")
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
