class PacksController < ApplicationController
  SEEDS = 1..999_999_999

  def latest
    gameweek = Gameweek.next_gameweek || Gameweek.current_gameweek || Gameweek.finished.ordered.last
    return render(:empty) unless gameweek

    redirect_to weekly_pack_path(gameweek: gameweek.fpl_id)
  end

  def weekly
    @gameweek = Gameweek.find_by!(fpl_id: params[:gameweek])
    @weekly = true
    @real = PackRealPoints.new(@gameweek) if @gameweek.is_finished
    play(@gameweek.fpl_id)
  end

  def new
    redirect_to pack_path(seed: rand(SEEDS))
  end

  def show
    @gameweek = Gameweek.next_gameweek
    play(params[:seed].to_i)
  end

  private

  def play(seed)
    @pack = PackDraw.call(gameweek: @gameweek, seed: seed)
    return render(:empty) unless @pack

    @hand = PackHand.parse(@pack, params[:hand])
    @score = PackScore.new(@pack) if @hand.complete?
    render :show
  end

  def hand_path(hand)
    code = hand.code.presence
    @weekly ? weekly_pack_path(gameweek: @gameweek.fpl_id, hand: code) : pack_path(seed: @pack.seed, hand: code)
  end
  helper_method :hand_path
end
