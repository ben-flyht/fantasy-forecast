class Performance < ApplicationRecord
  belongs_to :player
  belongs_to :gameweek
  belongs_to :team

  validates :gameweek_score, numericality: true, allow_nil: true
  validates :player_id, uniqueness: { scope: :gameweek_id }
end
