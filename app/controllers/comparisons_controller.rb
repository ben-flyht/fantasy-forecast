class ComparisonsController < ApplicationController
  include ServesCards

  SEASON = "season".freeze

  def index
    @gameweek = Gameweek.next_gameweek
    @horizon = horizon
    @pairs = PopularComparisons.call(gameweek: @gameweek, horizon: @horizon)
  end

  def show
    @comparison = Comparison.parse(params[:pair])
    return if redirect_to_one_player
    return if redirect_to_canonical_order

    load_head_to_head

    respond_to do |format|
      format.html { @related = related_comparisons }
      format.png { send_card("cards/comparison", card_key) }
    end
  end

  private

  def horizon
    params[:horizon] == SEASON ? SEASON : "gameweek"
  end

  def load_head_to_head
    @gameweek = Gameweek.next_gameweek
    @horizon = horizon
    @head_to_head = HeadToHead.call(
      left: @comparison.left, right: @comparison.right,
      gameweek: @gameweek, horizon: @horizon
    )
  end

  # A player against himself is not a question, so it is answered by his own page.
  def redirect_to_one_player
    return false if @comparison.valid?

    redirect_to player_path(@comparison.left), status: :moved_permanently
    true
  end

  # Both orders are the same argument, and only one of them is the page.
  def redirect_to_canonical_order
    return false if params[:pair] == @comparison.slug

    redirect_to comparison_path(pair: @comparison.slug, format: params[:format]),
                status: :moved_permanently
    true
  end

  def related_comparisons
    RelatedComparisons.call(players: @comparison.players, gameweek: @gameweek, horizon: @horizon)
  end

  def card_key
    [ "comparison_card", @comparison.slug, @horizon, @head_to_head.forecast_at&.to_i ].join("/")
  end
end
