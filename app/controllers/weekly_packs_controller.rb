class WeeklyPacksController < ApplicationController
  include PackManager

  before_action :require_manager, only: :show

  def landing
    @gameweek = Gameweek.next_gameweek
    @manager = Manager.new
    @entry = WeeklyPack.find_by(gameweek: @gameweek)&.entry_for(current_manager) if @gameweek
  end

  def show
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    @weekly = WeeklyPack.for(@gameweek)
    return render("packs/empty") unless @weekly

    @pack = @weekly.pack
    @entry = @weekly.entry_for(current_manager)
    return show_entry if @entry
    return render(:closed) if @weekly.locked?

    show_hand
  end

  private

  def show_entry
    @hand = @entry.pack_hand
    @score = PackScore.new(@pack)
    @real = PackRealScore.new(@gameweek)
    render "packs/show"
  end

  def show_hand
    @hand = PackHand.parse(@pack, params[:hand])
    return redirect_to(weekly_pack_path(gameweek: @gameweek.fpl_id)) unless @hand

    @score = PackScore.new(@pack) if @hand.complete?
    render "packs/show"
  end

  def hand_path(hand) = weekly_pack_path(gameweek: @gameweek.fpl_id, hand: hand.code.presence)
  helper_method :hand_path
end
