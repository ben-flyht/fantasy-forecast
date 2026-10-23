class PacksController < ApplicationController
  include PackSignIn

  SEEDS = 1..999_999_999

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
    @board = PackLeaderboard.new(@gameweek)
  end

  def practice
    resume = session[:practice]
    if resume.present?
      return redirect_to(pack_path(seed: resume["seed"], hand: resume["hand"].presence))
    end

    start
  end

  def start
    session.delete(:practice)
    redirect_to pack_path(seed: rand(SEEDS))
  end

  def show
    @gameweek = Gameweek.next_gameweek
    @pack = PackDraw.call(gameweek: @gameweek, seed: params[:seed].to_i)
    return render(:empty) unless @pack

    hand = PackHand.parse(@pack, params[:hand])
    session[:practice] = hand.complete? ? nil : { "seed" => @pack.seed, "hand" => hand.code }
    show_hand(hand)
  end

  private

  def unopened = render(@gameweek.start_time.future? ? :not_open : :closed)

  def play_selection
    @pack = @selection.pack
    @real = PackRealPoints.new(@gameweek) if @gameweek.start_time.past?
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

  def weekly? = @selection.present?
  helper_method :weekly?

  def shared? = @shared.present?
  helper_method :shared?

  def pick_path(hand, choice)
    return pack_path(seed: @pack.seed, hand: hand.keeping(choice).code) unless weekly?

    weekly_pack_picks_path(gameweek: @gameweek.fpl_id, keep: choice ? PackHand::LETTERS[choice] : PackHand::FORFEIT)
  end
  helper_method :pick_path

  def pick_method = (:post if weekly?)
  helper_method :pick_method

  def share_path = pack_selection_url(@selection)
  helper_method :share_path
end
