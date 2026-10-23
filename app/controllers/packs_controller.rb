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
    @entry ? show_hand(@entry.pack_hand) : weekly_hand
  end

  def leaderboard
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    @weekly_pack = WeeklyPack.find_by(gameweek: @gameweek)
    @board = PackLeaderboard.new(@weekly_pack) if @weekly_pack
  end

  def practice
    resume = session[:practice]
    if resume.present?
      return redirect_to(pack_path(seed: resume["seed"], hand: resume["hand"].presence),
                         notice: "Picking up your practice pack where you left off.")
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
    hand = PackHand.parse(@pack, params[:hand])
    return show_hand(hand) if hand.complete?
    return redirect_to(pack_landing_path) unless current_manager
    return render(:closed) if @weekly_pack.locked?

    show_hand(hand)
  end

  def show_hand(hand)
    @hand = hand
    @board = PackLeaderboard.new(@weekly_pack) if @entry
    render :show
  end

  def weekly? = @weekly_pack.present?
  helper_method :weekly?

  def hand_path(hand)
    code = hand.code.presence
    weekly? ? weekly_pack_path(gameweek: @gameweek.fpl_id, hand: code) : pack_path(seed: @pack.seed, hand: code)
  end
  helper_method :hand_path
end
