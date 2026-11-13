class PacksController < ApplicationController
  include PackSignIn

  def latest
    @gameweek = playing_gameweek
    return render(:sign_in) unless current_user

    @gameweek ? redirect_to(weekly_pack_path(gameweek: @gameweek.fpl_id)) : render(:empty)
  end

  def weekly
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    return redirect_to(pack_landing_path) unless current_user

    @selection = Selection.deal(current_user, @gameweek)
    return unopened unless @selection

    @dealing = @selection.picks.empty? && !@gameweek.started?
    play_selection
  end

  def leaderboard
    latest = Gameweek.latest_started
    @gameweek = params[:gameweek] ? Gameweek.find_by!(fpl_id: params[:gameweek]) : latest || Gameweek.next_gameweek
    return render(:empty) unless @gameweek
    return redirect_to(pack_current_leaderboard_path) if latest && !@gameweek.started?

    @board = PackLeaderboard.new(@gameweek)
    @real = PackRealPoints.new(@gameweek) if @gameweek.started?
  end

  def season
    @accuracy = params[:board] == "accuracy"
    @board = PackSeasonLeaderboard.new
  end

  private

  def pros = @pros ||= PackSeasonLeaderboard.new.pros.to_set
  helper_method :pros

  def unopened = render(@gameweek.started? ? :closed : :not_open)

  def play_selection
    @pack = @selection.pack
    @real = PackRealPoints.new(@gameweek) if @gameweek.started?
    @board = PackLeaderboard.new(@gameweek)
    @hand = @selection.pack_hand
    render :show
  end

  def playing_gameweek
    current = Gameweek.current_gameweek
    return current if current && !current.is_finished

    Gameweek.next_gameweek || current || Gameweek.finished.ordered.last
  end
end
