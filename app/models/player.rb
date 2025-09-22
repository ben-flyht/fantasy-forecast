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
  has_many :performances, dependent: :destroy

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def total_score(up_to_gameweek = nil)
    scope = performances

    if up_to_gameweek
      # Include performances for gameweeks up to and including the specified gameweek
      gameweek_record = up_to_gameweek.is_a?(Gameweek) ? up_to_gameweek : Gameweek.find_by(fpl_id: up_to_gameweek)
      return 0 unless gameweek_record

      scope = scope.joins(:gameweek).where("gameweeks.fpl_id <= ?", gameweek_record.fpl_id)
    end

    scope.sum(:gameweek_score)
  end
end
