class PackProfilesController < ApplicationController
  include PackSignIn

  before_action -> { redirect_to(pack_landing_path) unless current_user }

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    return render(:edit, status: :unprocessable_entity) unless @user.update(params.permit(:first_name, :last_name, :username))

    redirect_to(params[:from] == "pack" ? pack_landing_path : pack_profile_path, notice: "Profile saved.")
  end
end
