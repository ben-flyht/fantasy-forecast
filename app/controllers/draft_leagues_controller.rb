class DraftLeaguesController < ApplicationController
  def create
    entry_id = params[:entry_id].to_s.strip

    unless entry_id.match?(/\A\d+\z/)
      redirect_back fallback_location: root_path, alert: "Entry ID must be a number"
      return
    end

    league_id = Fpl::DraftLeagueStatus.lookup_league_id(entry_id)
    unless league_id
      redirect_back fallback_location: root_path, alert: "Draft team not found"
      return
    end

    cookies[:draft_entry_id] = { value: entry_id, expires: 1.year.from_now }
    cookies[:draft_league_id] = { value: league_id.to_s, expires: 1.year.from_now }
    redirect_back fallback_location: root_path, notice: "Draft league connected"
  end

  def destroy
    cookies.delete(:draft_entry_id)
    cookies.delete(:draft_league_id)
    redirect_back fallback_location: root_path, notice: "Draft league disconnected"
  end
end
