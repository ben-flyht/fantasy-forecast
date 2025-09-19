class Prediction < ApplicationRecord
  belongs_to :user
  belongs_to :player
  belongs_to :gameweek, optional: true

  # Enums
  enum :season_type, { weekly: 0, rest_of_season: 1 }
  enum :category, { must_have: 0, better_than_expected: 1, worse_than_expected: 2 }

  # Callbacks
  before_validation :assign_next_gameweek!, if: :weekly?

  # Validations
  validates :gameweek, presence: true, if: :weekly?
  validates :season_type, presence: true
  validates :category, presence: true

  # Uniqueness constraint: one prediction per user/player/gameweek/season_type
  validates :user_id, uniqueness: { scope: [ :player_id, :gameweek_id, :season_type ] }

  # Scopes
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :weekly_predictions, -> { where(season_type: :weekly) }
  scope :season_predictions, -> { where(season_type: :rest_of_season) }

  # Additional scopes for querying
  scope :for_gameweek, ->(gameweek_id) { where(gameweek_id: gameweek_id) }
  scope :for_season_type, ->(season_type) { where(season_type: season_type) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  # Backwards compatibility - map week to gameweek fpl_id
  scope :by_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }
  scope :for_week, ->(week) { joins(:gameweek).where(gameweeks: { fpl_id: week }) }

  # Class methods for aggregation
  def self.consensus_for_week(week)
    joins(:gameweek).where(gameweeks: { fpl_id: week })
      .group(:player_id, :category)
      .select("player_id, category, COUNT(*) as count")
      .order("count DESC")
  end

  def self.consensus_rest_of_season
    where(season_type: "rest_of_season")
      .group(:player_id, :category)
      .select("player_id, category, COUNT(*) as count")
      .order("count DESC")
  end

  def self.top_players_by_category_for_week(week, category, limit = 10)
    joins(:gameweek).where(gameweeks: { fpl_id: week }, category: category)
      .group(:player_id)
      .select("player_id, COUNT(*) as count")
      .order("count DESC")
      .limit(limit)
  end

  # Class method for auto-assignment
  def self.assign_next_gameweek!
    next_gameweek = Gameweek.next_gameweek
    next_gameweek&.id
  end

  private

  # Instance method for auto-assignment
  def assign_next_gameweek!
    return unless weekly?
    return if gameweek.present?  # Don't override if gameweek is already set

    next_gameweek = Gameweek.next_gameweek
    if next_gameweek
      self.gameweek = next_gameweek
    else
      errors.add(:gameweek, "No next gameweek available")
    end
  end
end
