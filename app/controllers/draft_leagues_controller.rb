class DraftLeaguesController < ApplicationController
  def create
    entry_id = extract_entry_id(params[:entry_id])
    return redirect_with_alert("Paste the link to your FPL Draft team's Points page, or your entry ID") unless entry_id

    league_id = Fpl::DraftLeagueStatus.lookup_league_id(entry_id)
    return redirect_with_alert("We couldn't find that Draft team. Check you copied the whole Points-page link") unless league_id

    save_draft_cookies(entry_id, league_id)
    redirect_to root_path
  end

  def destroy
    cookies.delete(:draft_entry_id)
    cookies.delete(:draft_league_id)
    redirect_to root_path
  end

  private

  # Accepts a full FPL Draft URL (the Points page looks like
  # draft.premierleague.com/entry/334926/event/1) or a bare entry ID, and
  # returns the entry ID. Nil if we can't find one.
  def extract_entry_id(input)
    input = input.to_s.strip
    if (match = input.match(%r{entry/(\d+)}))
      match[1]
    elsif input.match?(/\A\d+\z/)
      input
    end
  end

  def save_draft_cookies(entry_id, league_id)
    cookies[:draft_entry_id] = { value: entry_id, expires: 1.year.from_now }
    cookies[:draft_league_id] = { value: league_id.to_s, expires: 1.year.from_now }
  end

  def redirect_with_alert(message)
    redirect_back fallback_location: root_path, alert: message
  end
end
