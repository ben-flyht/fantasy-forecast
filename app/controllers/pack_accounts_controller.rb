class PackAccountsController < ApplicationController
  include PackManager

  before_action :require_manager

  def update
    if current_manager.update(nickname: params[:nickname].to_s)
      redirect_to my_packs_path, notice: "You are #{current_manager.nickname} on the leaderboard now."
    else
      redirect_to my_packs_path, alert: current_manager.errors.full_messages.to_sentence
    end
  end
end
