class PackSignInsController < ApplicationController
  include PackSignIn

  EXPIRED = "That link has expired or has already been used. Ask for a new one below."

  rate_limit to: 5, within: 10.minutes, only: :create,
             with: -> { redirect_to pack_landing_path, alert: "Too many requests. Try again in a few minutes." }

  def create
    @user = User.find_or_initialize_by(email: User.normalize_value_for(:email, params[:email].to_s))
    return render("packs/sign_in", status: :unprocessable_entity) unless @user.save

    PackMailer.with(user: @user, gameweek: Gameweek.next_gameweek).pack_link.deliver_later if @user.send_link?
    render :sent
  end

  def show
    @user = linked_user
    redirect_to(pack_landing_path, alert: EXPIRED) unless @user
  end

  def confirm
    user = linked_user
    return redirect_to(pack_landing_path, alert: EXPIRED) unless user

    user.signed_in!
    sign_in_user(user)
    redirect_to pack_landing_path
  end

  def destroy
    sign_out_user
    redirect_to pack_landing_path, notice: "Signed out."
  end

  private

  def linked_user = User.find_by_token_for(:pack_link, params[:token])
end
