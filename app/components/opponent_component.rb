# frozen_string_literal: true

class OpponentComponent < ViewComponent::Base
  def initialize(player:, gameweek:, matches_by_team: nil)
    @player = player
    @gameweek = gameweek
    @matches_by_team = matches_by_team
  end

  def opponents
    return [] unless @player&.team && @gameweek

    if @matches_by_team
      # Use preloaded data to avoid N+1
      matches = @matches_by_team[@player.team_id] || []
    else
      # Fallback to query (for backward compatibility)
      gameweek_record = @gameweek.is_a?(Gameweek) ? @gameweek : Gameweek.find_by(fpl_id: @gameweek)
      return [] unless gameweek_record

      matches = Match.includes(:home_team, :away_team)
                     .where(gameweek: gameweek_record)
                     .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)
    end

    matches.map do |match|
      if match.home_team_id == @player.team_id
        { team: match.away_team, home: true }
      else
        { team: match.home_team, home: false }
      end
    end
  end
end
