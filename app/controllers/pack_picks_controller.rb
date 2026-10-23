class PackPicksController < ApplicationController
  include PackManager

  def create
    gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    return redirect_to(pack_landing_path) unless current_manager

    entry = PackEntry.find_or_initialize_by(manager: current_manager, weekly_pack: WeeklyPack.find_by!(gameweek: gameweek))
    entry.hand ||= ""
    entry.pick(params[:keep])
    redirect_to weekly_pack_path(gameweek: gameweek.fpl_id)
  end
end
