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

  def given_name
    player_name.given
  end

  def display_name
    player_name.display
  end

  def slug
    full_name.parameterize
  end

  def to_param
    "#{slug}-#{fpl_id}"
  end

  def photo_url(size: "40x40")
    return nil unless code.present?
    "https://resources.premierleague.com/premierleague25/photos/players/#{size}/#{code}.png"
  end

  def cutout_url
    return nil unless code.present?
    "https://resources.premierleague.com/premierleague25/photos/players/110x140/#{code}.png"
  end

  # Get chance_of_playing from statistics for the current/next gameweek
  # Uses find on loaded association to avoid N+1 queries when statistics are preloaded
  def chance_of_playing(gameweek = nil)
    gw_id = resolve_gameweek_id(gameweek)
    return 100 unless gw_id

    stat = statistics.find { |s| s.gameweek_id == gw_id && s.type == "chance_of_playing" }
    stat&.value&.to_i || 100
  end

  private

  def player_name
    @player_name ||= PlayerName.new(first_name: first_name, last_name: last_name, short_name: short_name)
  end

  def resolve_gameweek_id(gameweek)
    gameweek ||= Gameweek.current_gameweek || Gameweek.next_gameweek
    return nil unless gameweek

    gameweek.is_a?(Gameweek) ? gameweek.id : Gameweek.find_by(fpl_id: gameweek)&.id
  end
end
