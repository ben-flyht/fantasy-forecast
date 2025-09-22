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

  # Scopes
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

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

  private

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
