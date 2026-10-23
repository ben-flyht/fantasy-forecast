class PacksController < ApplicationController
  include PackManager

  SEEDS = 1..999_999_999

  def latest
    return render(:sign_in) unless current_manager

    gameweek = playing_gameweek
    gameweek ? redirect_to(weekly_pack_path(gameweek: gameweek.fpl_id)) : render(:empty)
  end

  def weekly
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    @weekly_pack = WeeklyPack.for(@gameweek) || WeeklyPack.find_by(gameweek: @gameweek)
    return unopened unless @weekly_pack

    @pack = @weekly_pack.pack
    @entry = @weekly_pack.entry_for(current_manager)
    @real = PackRealPoints.new(@gameweek) if @gameweek.start_time.past?
    weekly_hand
  end

  def leaderboard
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    @weekly_pack = WeeklyPack.find_by(gameweek: @gameweek)
    @board = PackLeaderboard.new(@weekly_pack) if @weekly_pack
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

  def unopened = render(@gameweek.start_time.future? ? :not_open : :empty)

  def playing_gameweek
    current = Gameweek.current_gameweek
    return current if current && !current.is_finished

    Gameweek.next_gameweek || current || Gameweek.finished.ordered.last
  end

  def weekly_hand
    shared = PackHand.parse(@pack, params[:hand])
    return shared_hand(shared) if shared_with_me?(shared)
    return redirect_to(pack_landing_path) unless current_manager
    return render(:closed) if @weekly_pack.locked? && @entry.nil?

    show_hand(@entry&.pack_hand || PackHand.new(@pack, keeps: []))
  end

  def shared_with_me?(hand) = hand.complete? && hand.code != @entry&.hand

  def shared_hand(hand)
    @shared = true
    show_hand(hand)
  end

  def show_hand(hand)
    @hand = hand
    @board = PackLeaderboard.new(@weekly_pack) if @entry
    render :show
  end

  def weekly? = @weekly_pack.present?
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

  def share_path = weekly_pack_url(gameweek: @gameweek.fpl_id, hand: @hand.code)
  helper_method :share_path
end
