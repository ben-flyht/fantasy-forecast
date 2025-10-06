# frozen_string_literal: true

class OpponentComponent < ViewComponent::Base
  def initialize(player:, gameweek:)
    @player = player
    @gameweek = gameweek
  end

  def opponents
    return [] unless @player&.team && @gameweek

    gameweek_record = @gameweek.is_a?(Gameweek) ? @gameweek : Gameweek.find_by(fpl_id: @gameweek)
    return [] unless gameweek_record

    matches = Match.includes(:home_team, :away_team)
                   .where(gameweek: gameweek_record)
                   .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)

    matches.map do |match|
      if match.home_team_id == @player.team_id
        { team: match.away_team, home: true }
      else
        { team: match.home_team, home: false }
      end
    end
  end
end
