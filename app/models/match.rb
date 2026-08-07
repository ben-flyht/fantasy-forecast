class Match < ApplicationRecord
  belongs_to :home_team, class_name: "Team"
  belongs_to :away_team, class_name: "Team"
  belongs_to :gameweek

  validates :fpl_id, presence: true, uniqueness: true

  # Every fixture in a gameweek, filed under both teams playing it, so a page can
  # ask what any one of them has that week without a query for each.
  def self.by_team(gameweek)
    includes(:home_team, :away_team).where(gameweek: gameweek)
      .each_with_object(Hash.new { |teams, id| teams[id] = [] }) do |match, teams|
        teams[match.home_team_id] << match
        teams[match.away_team_id] << match
      end
  end

  # FPL's official fixture difficulty rating (1 easiest, 5 hardest) for the given
  # team in this match. The API rates each side separately.
  def difficulty_for(team_id)
    team_id == home_team_id ? home_difficulty : away_difficulty
  end

  # A fixture is stored once, from neither side's point of view, so who a team plays
  # and where has to be asked rather than read.
  def opponent_for(team_id)
    team_id == home_team_id ? away_team : home_team
  end

  def home_for?(team_id)
    team_id == home_team_id
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
