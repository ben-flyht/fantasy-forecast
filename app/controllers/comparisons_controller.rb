class ComparisonsController < ApplicationController
  include ServesCards

  SEASON = "season".freeze

  def index
    @gameweek = Gameweek.next_gameweek
    @horizon = horizon
    @most_requested = MostRequestedComparisons.call
    @pairs = PopularComparisons.call(gameweek: @gameweek, horizon: @horizon)
  end

  # Who you might mean, for the two boxes on the hub. Names, and enough beside each
  # to tell two Gabriels apart.
  def search
    players = PlayerSearch.call(term: params[:q], exclude: params[:exclude])

    render json: players.map { |player|
      { param: player.to_param, name: player.display_name, full_name: player.full_name,
        team: player.team&.short_name, position: FantasyForecast::POSITION_CONFIG.dig(player.position, :display_name),
        photo: player.photo_url }
    }
  end

  def show
    @comparison = Comparison.parse(params[:pair])
    return if redirect_to_one_player
    return if redirect_to_canonical_order

    load_head_to_head

    respond_to do |format|
      format.html { render_comparison }
      format.png { send_comparison_card }
    end
  end

  private

  def render_comparison
    record_request
    @related = related_comparisons
  end

  # Every argument that reaches the page is counted against its canonical slug, so the
  # hub and the sitemap can offer the ones people actually ask. See
  # MostRequestedComparisons for what is then surfaced, which is pairs only.
  def record_request
    ComparisonRequest.record(@comparison.slug)
  end

  def horizon
    Horizon.find(params[:horizon]).key
  end

  def load_head_to_head
    @gameweek = Gameweek.next_gameweek
    @horizon = horizon
    @head_to_head = HeadToHead.call(
      left: @comparison.left, right: @comparison.right,
      gameweek: @gameweek, horizon: @horizon
    )
    @forecast_at = Forecast.where(gameweek: @gameweek, horizon: @horizon).maximum(:updated_at)
    @stats = ComparisonStats.call(left: @comparison.left, right: @comparison.right)
  end

  # The card is drawn for two players and only two, so a comparison of groups has no
  # picture yet rather than a picture of half of it. The page says so by not offering
  # one; this is here for the address somebody types anyway.
  def send_comparison_card
    raise ActiveRecord::RecordNotFound, "No card for a group yet" if @comparison.group?

    send_card("cards/comparison", card_key)
  end

  # A player against himself is not a question, so it is answered by his own page.
  # Naming him twice in a bigger argument is not a question either, and there is no
  # page that answers that one.
  def redirect_to_one_player
    return false if @comparison.valid?

    player = @comparison.one_player
    raise ActiveRecord::RecordNotFound, "Not a question: #{params[:pair]}" unless player

    redirect_to player_path(player), status: :moved_permanently
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
