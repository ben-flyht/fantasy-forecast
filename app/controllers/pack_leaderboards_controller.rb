class PackLeaderboardsController < ApplicationController
  include PackManager

  def show
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    @weekly = WeeklyPack.find_by(gameweek: @gameweek)
    @board = PackLeaderboard.new(@weekly) if @weekly
  end
end
