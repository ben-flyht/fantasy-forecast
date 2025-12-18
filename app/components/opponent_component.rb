# frozen_string_literal: true

class OpponentComponent < ViewComponent::Base
  def initialize(player:, gameweek:, matches_by_team: nil)
    @player = player
    @gameweek = gameweek
    @matches_by_team = matches_by_team
  end

  def opponents
    return [] unless @player&.team && @gameweek

    matches.map { |match| build_opponent(match) }
  end

  private

  def matches
    @matches_by_team ? matches_from_preloaded : matches_from_query
  end

  def matches_from_preloaded
    @matches_by_team[@player.team_id] || []
  end

  def matches_from_query
    gameweek_record = @gameweek.is_a?(Gameweek) ? @gameweek : Gameweek.find_by(fpl_id: @gameweek)
    return [] unless gameweek_record

    Match.includes(:home_team, :away_team)
         .where(gameweek: gameweek_record)
         .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)
  end

  def build_opponent(match)
    if match.home_team_id == @player.team_id
      { team: match.away_team, home: true }
    else
      { team: match.home_team, home: false }
    end
  end
end
