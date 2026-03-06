class DraftLeaguesController < ApplicationController
  def create
    entry_id = params[:entry_id].to_s.strip
    return redirect_with_alert("Entry ID must be a number") unless entry_id.match?(/\A\d+\z/)

    league_id = Fpl::DraftLeagueStatus.lookup_league_id(entry_id)
    return redirect_with_alert("Draft team not found") unless league_id

    save_draft_cookies(entry_id, league_id)
    redirect_to root_path
  end

  def destroy
    cookies.delete(:draft_entry_id)
    cookies.delete(:draft_league_id)
    redirect_to root_path
  end

  private

  def save_draft_cookies(entry_id, league_id)
    cookies[:draft_entry_id] = { value: entry_id, expires: 1.year.from_now }
    cookies[:draft_league_id] = { value: league_id.to_s, expires: 1.year.from_now }
  end

  def redirect_with_alert(message)
    redirect_back fallback_location: root_path, alert: message
  end
end
