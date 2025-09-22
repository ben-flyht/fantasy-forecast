class Performance < ApplicationRecord
  belongs_to :player
  belongs_to :gameweek

  validates :gameweek_score, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :player_id, uniqueness: { scope: :gameweek_id }
end
