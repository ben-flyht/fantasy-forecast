class ComparisonsController < ApplicationController
  include ServesCards

  SEASON = "season".freeze

  def index
    @gameweek = Gameweek.next_gameweek
    @horizon = horizon
    @most_requested = MostRequestedComparisons.call(gameweek: @gameweek, horizon: @horizon)
    @pairs = PopularComparisons.call(gameweek: @gameweek, horizon: @horizon)
  end

  # Who you might mean, for the two boxes on the hub. Names, and enough beside each
  # to tell two Gabriels apart.
  def search
    players = PlayerSearch.call(term: params[:q], exclude: params[:exclude])

    render json: players.map { |player|
      { param: player.comparison_param, name: player.display_name, full_name: player.full_name,
        team: player.team&.short_name, position: FantasyForecast::POSITION_CONFIG.dig(player.position, :display_name),
        photo: player.photo_url }
    }
  end

  def show
    @comparison = Comparison.parse(params[:pair])
    return redirect_to comparisons_path if @comparison.empty?
    return if redirect_to_one_player
    return if redirect_to_canonical_order
    return render_building unless @comparison.answerable?

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

  # A side still being filled has no answer to draw, so the page is the builder with
  # what there is so far. It is reached by keeping the address in step with the builder,
  # so a half-built comparison can be shared, bookmarked or reloaded and picked back up.
  def render_building
    respond_to do |format|
      format.html { render :show }
      format.png { head :not_found }
    end
  end

  # Every argument that reaches the page is counted against its canonical slug, so the
  # hub and the sitemap can offer the ones people actually ask. See
  # MostRequestedComparisons for what is then surfaced, which is pairs only.
  #
  # Once a session, though: a manager editing his way to a comparison, or coming back
  # to it, is one person asking, not fifty, and the live editor would otherwise count
  # a hit for every keystroke that lands on a page.
  def record_request
    return unless @gameweek && first_in_session?

    ComparisonRequest.record(@comparison, @gameweek)
  end

  # Held once, not requested one at a time.
  SESSION_MEMORY = 50

  # Which comparisons this session has already counted, keyed by the gameweek as well
  # as the slug so a new week counts afresh, and kept as short digests so the slugs — a
  # side of fifteen is a long one — do not fill the cookie, capped so it cannot grow.
  def first_in_session?
    key = Digest::SHA1.hexdigest("#{@gameweek.id}:#{@comparison.slug}").first(12)
    seen = session[:compared] || []
    return false if seen.include?(key)

    session[:compared] = ([ key ] + seen).first(SESSION_MEMORY)
    true
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
