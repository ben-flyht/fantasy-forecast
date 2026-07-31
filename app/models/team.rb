class Team < ApplicationRecord
  COLORS = {
    "ARS" => "#EF0107", "AVL" => "#670E36", "BOU" => "#DA291C", "BRE" => "#E30613",
    "BHA" => "#0057B8", "CHE" => "#034694", "COV" => "#6CB4EE", "CRY" => "#1B458F",
    "EVE" => "#003399", "FUL" => "#1D1D1D", "HUL" => "#F5A12D", "IPS" => "#3A64A3",
    "LEE" => "#1D428A", "LIV" => "#C8102E", "MCI" => "#6CABDD", "MUN" => "#DA291C",
    "NEW" => "#241F20", "NFO" => "#DD0000", "TOT" => "#132257", "SUN" => "#EB172B"
  }.freeze

  LIGHT_SHIRTS = %w[MCI COV HUL].freeze

  DEFAULT_COLOR = "#374151".freeze

  # Validations
  validates :name, presence: true
  validates :short_name, presence: true
  validates :fpl_id, presence: true, uniqueness: true

  # Associations
  has_many :players
  has_many :home_matches, class_name: "Match", foreign_key: "home_team_id", dependent: :destroy
  has_many :away_matches, class_name: "Match", foreign_key: "away_team_id", dependent: :destroy

  def matches
    Match.where("home_team_id = ? OR away_team_id = ?", id, id)
  end

  def badge_url
    return nil unless code.present?
    "https://resources.premierleague.com/premierleague25/badges/#{code}.svg"
  end

  def color
    COLORS.fetch(short_name, DEFAULT_COLOR)
  end

  def on_light?
    LIGHT_SHIRTS.include?(short_name)
  end

  # FPL strength ratings (higher = stronger), split by venue. Used to rate how
  # hard a fixture is for a given player position (attacker faces the opponent's
  # defence; defender/keeper faces the opponent's attack).
  def attack_strength(venue)
    venue == :home ? strength_attack_home : strength_attack_away
  end

  def defence_strength(venue)
    venue == :home ? strength_defence_home : strength_defence_away
  end
end
