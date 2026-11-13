module PacksHelper
  def leaderboard_tabs(gameweek:, season: false)
    [
      PageHeadingComponent::Horizon.new(label: week_tab_label(gameweek), url: pack_leaderboard_path(gameweek: gameweek.fpl_id), current: !season),
      PageHeadingComponent::Horizon.new(label: "Season", url: pack_season_leaderboard_path, current: season)
    ]
  end

  private

  def week_tab_label(gameweek)
    gameweek == Gameweek.latest_started ? "This week" : "Gameweek #{gameweek.fpl_id}"
  end
end
