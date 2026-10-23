class PacksController < ApplicationController
  include PackManager

  SEEDS = 1..999_999_999

  def latest
    return render(:sign_in) unless current_manager

    gameweek = Gameweek.next_gameweek || Gameweek.current_gameweek || Gameweek.finished.ordered.last
    gameweek ? redirect_to(weekly_pack_path(gameweek: gameweek.fpl_id)) : render(:empty)
  end

  def weekly
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    @weekly_pack = WeeklyPack.for(@gameweek) || WeeklyPack.find_by(gameweek: @gameweek)
    return render(:empty) unless @weekly_pack

    @pack = @weekly_pack.pack
    @entry = @weekly_pack.entry_for(current_manager)
    @real = PackRealPoints.new(@gameweek) if @gameweek.start_time.past?
    @entry ? show_hand(@entry.pack_hand) : weekly_hand
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

  def weekly_hand
    hand = PackHand.parse(@pack, params[:hand])
    return show_hand(hand) if hand.complete?
    return redirect_to(pack_landing_path) unless current_manager
    return render(:closed) if @weekly_pack.locked?

    show_hand(hand)
  end

  def show_hand(hand)
    @hand = hand
    @score = PackScore.new(@pack) if @hand.complete?
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
