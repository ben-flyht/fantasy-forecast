# frozen_string_literal: true

class FixtureComponent < ViewComponent::Base
  def initialize(match:, player:, show_badge: true)
    @match = match
    @player = player
    @show_badge = show_badge
  end

  def show_badge?
    @show_badge
  end

  def opponent
    home_match? ? @match.away_team : @match.home_team
  end

  def home_match?
    @player.team_id == @match.home_team_id
  end

  def venue
    home_match? ? "H" : "A"
  end

  def player_xg
    home_match? ? @match.home_team_expected_goals : @match.away_team_expected_goals
  end

  def opponent_xg
    home_match? ? @match.away_team_expected_goals : @match.home_team_expected_goals
  end
end
