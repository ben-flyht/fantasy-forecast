class PackPicksController < ApplicationController
  include PackSignIn

  def create
    gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    return redirect_to(pack_landing_path) unless current_user

    Selection.deal(current_user, gameweek)&.choose(pair, params[:keep].to_s)
    redirect_to weekly_pack_path(gameweek: gameweek.fpl_id), status: :see_other
  end

  private

  def pair = Integer(params[:pair].to_s, exception: false)
end
