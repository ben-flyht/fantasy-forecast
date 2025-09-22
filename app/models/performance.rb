class Performance < ApplicationRecord
  belongs_to :player
  belongs_to :gameweek

  validates :gameweek_score, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :player_id, uniqueness: { scope: :gameweek_id }
end
