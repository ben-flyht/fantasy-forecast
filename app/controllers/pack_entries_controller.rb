class PackEntriesController < ApplicationController
  include PackManager

  before_action :require_manager

  def index
    @entries = current_manager.pack_entries.includes(weekly_pack: :gameweek).order(created_at: :desc)
  end

  def create
    gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    weekly = WeeklyPack.find_by!(gameweek: gameweek)
    destination = weekly_pack_path(gameweek: gameweek.fpl_id)
    return redirect_to(destination, alert: "The deadline has passed.") if weekly.locked?

    entry = enter(weekly)
    if entry.save
      redirect_to destination, notice: "Locked in. Good luck."
    else
      redirect_to destination, alert: entry.errors.full_messages.to_sentence
    end
  end

  private

  def enter(weekly)
    entry = weekly.pack_entries.new(manager: current_manager, hand: params[:hand].to_s)
    entry.expected_points = PackScore.new(weekly.pack).points(entry.pack_hand) if entry.pack_hand&.complete?
    entry
  end
end
