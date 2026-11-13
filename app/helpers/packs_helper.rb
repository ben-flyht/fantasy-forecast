module PacksHelper
  def leaderboard_tabs(gameweek:, season: false)
    [
      PageHeadingComponent::Horizon.new(label: week_tab_label(gameweek), url: week_tab_url(gameweek), current: !season),
      PageHeadingComponent::Horizon.new(label: "Season", url: pack_season_leaderboard_path, current: season)
    ]
  end

  def leaderboard_steps(gameweek)
    played = Gameweek.started.where(id: Selection.select(:gameweek_id))
    {
      previous: played.where(fpl_id: ...gameweek.fpl_id).ordered.last,
      next: played.where(fpl_id: (gameweek.fpl_id + 1)..).ordered.first
    }
  end

  private

  def current_week?(gameweek) = gameweek == Gameweek.latest_started

  def week_tab_label(gameweek) = current_week?(gameweek) ? "This week" : "Gameweek #{gameweek.fpl_id}"

  def week_tab_url(gameweek) = current_week?(gameweek) ? pack_current_leaderboard_path : pack_leaderboard_path(gameweek: gameweek.fpl_id)
end
