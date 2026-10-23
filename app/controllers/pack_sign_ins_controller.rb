class PackSignInsController < ApplicationController
  include PackSignIn

  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to pack_landing_path, alert: "Too many requests. Try again in a few minutes." }

  def create
    @user = User.find_or_initialize_by(email: User.normalize_value_for(:email, params[:email].to_s))
    @user.assign_attributes(params.permit(:first_name, :last_name)) if @user.new_record?
    return render("packs/sign_in", status: :unprocessable_entity) unless @user.save

    PackMailer.with(user: @user, gameweek: Gameweek.next_gameweek).pack_link.deliver_later
    render :sent
  end

  def show
    user = User.find_by_token_for(:pack_link, params[:token])
    return redirect_to(pack_landing_path, alert: "That link has expired. Ask for a new one below.") unless user

    sign_in_user(user)
    redirect_to pack_landing_path
  end

  def destroy
    sign_out_user
    redirect_to pack_landing_path, notice: "Signed out."
  end
end
