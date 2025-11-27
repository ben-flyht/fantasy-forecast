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
  validates :fpl_id, presence: true, uniqueness: true
  validates :position, presence: true

  # Associations
  belongs_to :team, optional: true  # Optional for now during migration
  has_many :forecasts, dependent: :destroy
  has_many :performances, dependent: :destroy
  has_many :statistics, dependent: :destroy

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def name
    full_name
  end

  def short_name
    # Use the short_name attribute if it exists, otherwise fall back to last name
    read_attribute(:short_name).presence || last_name
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

  # Access the cached total score from SQL query or fall back to dynamic calculation
  def total_score_cached
    # If we have a cached value from the SQL query, use it
    if attributes.key?("total_score_cached")
      attributes["total_score_cached"].to_i
    else
      # Fall back to the dynamic calculation
      total_score
    end
  end

  def photo_url(size: "110x140")
    return nil unless code.present?
    "https://resources.premierleague.com/premierleague25/photos/players/#{size}/#{code}.png"
  end
end
