class PackProfilesController < ApplicationController
  include PackSignIn

  before_action -> { redirect_to(pack_landing_path) unless current_user }

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    return render(:edit, status: :unprocessable_entity) unless @user.update(entry_name: params[:entry_name].to_s)

    redirect_to(params[:from] == "pack" ? pack_landing_path : pack_profile_path, notice: "Entry name saved.")
  end
end
