class PackMailer < ApplicationMailer
  def pack_link
    @user = params[:user]
    @gameweek = params[:gameweek]
    @link = pack_sign_in_url(token: @user.generate_token_for(:pack_link))

    mail to: @user.email, subject: @gameweek ? "Your Gameweek #{@gameweek.fpl_id} Pack of the Week is ready" : "Your Fantasy Forecast sign-in link"
  end
end
