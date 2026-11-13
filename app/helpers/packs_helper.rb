module PacksHelper
  def play_tabs(current:, gameweek: nil)
    [
      PageHeadingComponent::Horizon.new(label: "Your pack", short_label: "Pack", url: pack_landing_path, current: current == :pack),
      PageHeadingComponent::Horizon.new(label: "Weekly", url: weekly_tab_url(gameweek, current), current: current == :weekly),
      PageHeadingComponent::Horizon.new(label: "Points", url: pack_season_leaderboard_path, current: current == :points),
      PageHeadingComponent::Horizon.new(label: "Accuracy", url: pack_season_accuracy_leaderboard_path, current: current == :accuracy)
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

  def weekly_tab_url(gameweek, current)
    return pack_current_leaderboard_path unless current == :weekly && gameweek && gameweek != Gameweek.latest_started

    pack_leaderboard_path(gameweek: gameweek.fpl_id)
  end
end
