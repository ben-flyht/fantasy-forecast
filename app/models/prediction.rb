class Prediction < ApplicationRecord
  belongs_to :user
  belongs_to :player

  # Enums
  enum :season_type, { weekly: 0, rest_of_season: 1 }
  enum :category, { must_have: 0, better_than_expected: 1, worse_than_expected: 2 }

  # Validations
  validates :week, presence: true, if: :weekly?
  validates :season_type, presence: true
  validates :category, presence: true

  # Uniqueness constraint: one prediction per user/player/week/season_type
  validates :user_id, uniqueness: { scope: [ :player_id, :week, :season_type ] }

  # Scopes
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_week, ->(week) { where(week: week) }
  scope :weekly_predictions, -> { where(season_type: :weekly) }
  scope :season_predictions, -> { where(season_type: :rest_of_season) }

  # Additional scopes for querying
  scope :for_week, ->(week) { where(week: week) }
  scope :for_season_type, ->(season_type) { where(season_type: season_type) }
  scope :for_player, ->(player_id) { where(player_id: player_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  # Class methods for aggregation
  def self.consensus_for_week(week)
    where(week: week)
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
    where(week: week, category: category)
      .group(:player_id)
      .select("player_id, COUNT(*) as count")
      .order("count DESC")
      .limit(limit)
  end
end
