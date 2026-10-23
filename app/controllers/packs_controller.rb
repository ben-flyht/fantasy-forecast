class PacksController < ApplicationController
  SEEDS = 1..999_999_999

  def new
    redirect_to pack_path(seed: rand(SEEDS))
  end

  def show
    @gameweek = Gameweek.next_gameweek
    @pack = PackDraw.call(gameweek: @gameweek, seed: params[:seed].to_i)
    return render(:empty) unless @pack

    @hand = PackHand.parse(@pack, params[:hand])
    return redirect_to(pack_path(seed: @pack.seed)) unless @hand

    @score = PackScore.new(@pack) if @hand.complete?
  end

  private

  def hand_path(hand) = pack_path(seed: @pack.seed, hand: hand.code.presence)
  helper_method :hand_path
end
