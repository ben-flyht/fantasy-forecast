class Player < ApplicationRecord
  POSITION_GK = "GK".freeze
  POSITION_DEF = "DEF".freeze
  POSITION_MID = "MID".freeze
  POSITION_FWD = "FWD".freeze

  enum :position, {
    goalkeeper: POSITION_GK,
    defender: POSITION_DEF,
    midfielder: POSITION_MID,
    forward: POSITION_FWD
  }

  # Validations
  validates :name, presence: true
  validates :team, presence: true
  validates :fpl_id, presence: true, uniqueness: true
  validates :position, presence: true

  # Associations
  has_many :predictions, dependent: :destroy
end
