class PackEntriesController < ApplicationController
  include PackManager

  def create
    gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    return redirect_to(pack_landing_path) unless current_manager

    entry = enter(WeeklyPack.find_by!(gameweek: gameweek))
    destination = weekly_pack_path(gameweek: gameweek.fpl_id)
    return redirect_to(destination) if entry.save

    redirect_to destination, alert: entry.errors.full_messages.to_sentence
  end

  private

  def enter(weekly_pack)
    PackEntry.new(manager: current_manager, weekly_pack: weekly_pack, hand: params[:hand].to_s)
  end
end
