class Match < ApplicationRecord
  belongs_to :home_team, class_name: "Team"
  belongs_to :away_team, class_name: "Team"
  belongs_to :gameweek

  validates :fpl_id, presence: true, uniqueness: true

  # FPL's official fixture difficulty rating (1 easiest, 5 hardest) for the given
  # team in this match. The API rates each side separately.
  def difficulty_for(team_id)
    team_id == home_team_id ? home_difficulty : away_difficulty
  end

  validates :home_team_id, presence: true
  validates :away_team_id, presence: true
  validates :gameweek_id, presence: true
  validate :teams_must_be_different

  private

  def teams_must_be_different
    errors.add(:away_team, "can't be the same as home team") if home_team_id == away_team_id
  end
end
