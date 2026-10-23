class PackSignInsController < ApplicationController
  include PackManager

  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to pack_landing_path, alert: "Too many requests. Try again in a few minutes." }

  def create
    @gameweek = Gameweek.next_gameweek
    @manager = Manager.find_or_initialize_by(email: Manager.normalize_value_for(:email, params[:email].to_s))
    @manager.nickname = params[:nickname] if @manager.new_record?

    if @gameweek && @manager.save
      PackMailer.with(manager: @manager, gameweek: @gameweek).pack_link.deliver_later
      render :sent
    else
      render "weekly_packs/landing", status: :unprocessable_entity
    end
  end

  def show
    manager = Manager.find_by_token_for(:pack_link, params[:token])
    return redirect_to(pack_landing_path, alert: "That link has expired. Ask for a new one below.") unless manager

    sign_in_manager(manager)
    gameweek = Gameweek.next_gameweek || Gameweek.current_gameweek
    redirect_to gameweek ? weekly_pack_path(gameweek: gameweek.fpl_id) : pack_landing_path
  end

  def destroy
    reset_session
    redirect_to pack_landing_path
  end
end
