class Ranking
  attr_reader :player_id, :name, :first_name, :last_name, :team, :team_id, :position,
              :consensus_score, :total_forecasts, :total_score

  def initialize(attributes = {})
    @player_id = attributes[:player_id]
    @name = attributes[:name]
    @first_name = attributes[:first_name]
    @last_name = attributes[:last_name]
    @team = attributes[:team]
    @team_id = attributes[:team_id]
    @position = attributes[:position]
    @consensus_score = attributes[:consensus_score] || 0
    @total_forecasts = attributes[:total_forecasts] || 0
    @total_score = attributes[:total_score] || 0
  end

  def positive_score?
    consensus_score > 0
  end

  def negative_score?
    consensus_score < 0
  end

  def neutral_score?
    consensus_score == 0
  end
end
