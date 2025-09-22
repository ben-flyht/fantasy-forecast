class Player < ApplicationRecord
  POSITION_GOALKEEPER = "goalkeeper".freeze
  POSITION_DEFENDER = "defender".freeze
  POSITION_MIDFIELDER = "midfielder".freeze
  POSITION_FORWARD = "forward".freeze

  enum :position, {
    goalkeeper: POSITION_GOALKEEPER,
    defender: POSITION_DEFENDER,
    midfielder: POSITION_MIDFIELDER,
    forward: POSITION_FORWARD
  }

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :team, presence: true
  validates :fpl_id, presence: true, uniqueness: true
  validates :position, presence: true

  # Associations
  has_many :forecasts, dependent: :destroy

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
