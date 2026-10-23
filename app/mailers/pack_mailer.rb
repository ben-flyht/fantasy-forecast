class PackMailer < ApplicationMailer
  def pack_link
    @manager = params[:manager]
    @gameweek = params[:gameweek]
    @link = pack_sign_in_url(token: @manager.generate_token_for(:pack_link))

    subject = @gameweek ? "Your Gameweek #{@gameweek.fpl_id} pack is ready to open" : "Your Fantasy Forecast sign-in link"
    mail to: @manager.email, subject: subject
  end

  def results
    @entry = params[:entry]
    @manager = @entry.manager
    @gameweek = @entry.weekly_pack.gameweek
    @standing = params[:standing]
    @next_gameweek = params[:next_gameweek]
    @next_link = next_link

    mail to: @manager.email, subject: "Gameweek #{@gameweek.fpl_id}: you scored #{@entry.real_points}, #{verdict}"
  end

  private

  def next_link
    pack_sign_in_url(token: @manager.generate_token_for(:pack_link)) if @next_gameweek
  end

  def verdict
    return "level with the forecast" if @entry.accuracy == @entry.forecast_accuracy

    @entry.accuracy > @entry.forecast_accuracy ? "beating the forecast" : "behind the forecast"
  end
end
