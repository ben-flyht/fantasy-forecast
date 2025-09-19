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
end
