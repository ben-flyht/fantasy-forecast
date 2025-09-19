class Player < ApplicationRecord
  # Enum for position
  enum :position, { GK: 0, DEF: 1, MID: 2, FWD: 3 }

  # Validations
  validates :name, presence: true
  validates :team, presence: true
  validates :fpl_id, presence: true, uniqueness: true
  validates :position, presence: true

  # Associations
  has_many :predictions, dependent: :destroy
end
