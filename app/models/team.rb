class Team < ApplicationRecord
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
end
