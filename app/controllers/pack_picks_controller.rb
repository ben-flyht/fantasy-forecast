class PackPicksController < ApplicationController
  include PackSignIn

  def create
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    return redirect_to(pack_landing_path) unless current_user

    selection = Selection.deal(current_user, @gameweek)
    return back_to_pack unless selection

    record(selection)
    respond_to do |format|
      format.turbo_stream
      format.html { back_to_pack }
    end
  end

  private

  def record(selection)
    selection.choose(pair, params[:keep].to_s)
    @hand = selection.reload.pack_hand
    @pair = pair if pair&.between?(0, @hand.pack.size - 1)
  end

  def back_to_pack = redirect_to(weekly_pack_path(gameweek: @gameweek.fpl_id), status: :see_other)

  def pair = Integer(params[:pair].to_s, exception: false)
end
