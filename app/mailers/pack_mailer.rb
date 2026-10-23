class PackMailer < ApplicationMailer
  def pack_link
    @manager = params[:manager]
    @gameweek = params[:gameweek]
    @link = pack_sign_in_url(token: @manager.generate_token_for(:pack_link))

    mail to: @manager.email, subject: @gameweek ? "Your Gameweek #{@gameweek.fpl_id} Pack of the Week is ready" : "Your Fantasy Forecast sign-in link"
  end
end
