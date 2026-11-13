class PacksController < ApplicationController
  include PackSignIn

  def latest
    return render(:sign_in) unless current_user

    gameweek = playing_gameweek
    gameweek ? redirect_to(weekly_pack_path(gameweek: gameweek.fpl_id)) : render(:empty)
  end

  def weekly
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    return redirect_to(pack_landing_path) unless current_user

    @selection = Selection.deal(current_user, @gameweek)
    return unopened unless @selection

    play_selection
  end

  def selection
    @selection = Selection.find(params[:id])
    return head(:not_found) unless @selection.complete?

    @shared = @selection.user != current_user
    @gameweek = @selection.gameweek
    play_selection
  end

  def leaderboard
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    latest = Gameweek.latest_started
    return redirect_to(pack_leaderboard_path(gameweek: latest.fpl_id)) if latest && !@gameweek.started?

    @board = PackLeaderboard.new(@gameweek)
    @real = PackRealPoints.new(@gameweek) if @gameweek.started?
  end

  def season
    @gameweek = Gameweek.latest_started
    @board = PackSeasonLeaderboard.new
  end

  private

  def unopened = render(@gameweek.started? ? :closed : :not_open)

  def play_selection
    @pack = @selection.pack
    @real = PackRealPoints.new(@gameweek) if @gameweek.started?
    @board = PackLeaderboard.new(@gameweek) unless @shared
    show_hand(@selection.pack_hand)
  end

  def playing_gameweek
    current = Gameweek.current_gameweek
    return current if current && !current.is_finished

    Gameweek.next_gameweek || current || Gameweek.finished.ordered.last
  end

  def show_hand(hand)
    @hand = hand
    render :show
  end

  def shared? = @shared.present?
  helper_method :shared?

  def pick_path(hand, choice)
    weekly_pack_picks_path(gameweek: @gameweek.fpl_id, keep: choice ? PackHand::LETTERS[choice] : PackHand::FORFEIT)
  end
  helper_method :pick_path

  def share_path = pack_selection_url(@selection)
  helper_method :share_path
end
