class PlayersController < ApplicationController
  include ServesCards

  # Facts about a player we report rather than rate. See #load_row_facts.
  ROW_FACT_TYPES = %w[now_cost selected_by_percent transfers_in transfers_out].freeze

  # How deep a list is worth reading in each position. Past this you are scrolling
  # through players nobody is choosing between, and the tail is where a forecast is
  # least reliable anyway: those are the players whose minutes we are guessing at.
  RANKING_DEPTH = {
    "goalkeeper" => 50, "defender" => 100, "midfielder" => 100, "forward" => 50
  }.freeze

  TENTHS_PER_MILLION = 10

  PRICE_STEP = 5

  # The horizon that spans every gameweek that remains, as the routes and the
  # stored forecasts both spell it.
  SEASON = "season".freeze

  POSITION_SINGULARS = {
    "goalkeepers" => "goalkeeper", "defenders" => "defender",
    "midfielders" => "midfielder", "forwards" => "forward"
  }.freeze

  before_action :set_filters, only: [ :index ]

  helper_method :season?, :horizon_label, :horizon_short, :horizon_param, :position_rankings_path,
                :horizon_url, :position_options

  def index
    return if redirect_to_clean_url
    return unless validate_gameweek

    load_rankings_page

    respond_to do |format|
      format.html
      format.png { send_card("cards/rankings", rankings_card_key) }
    end
  end

  def show
    @player = find_player_from_param
    return if redirect_to_canonical_player

    load_player

    respond_to do |format|
      format.html { load_player_page }
      format.png { send_card("cards/player", player_card_key) }
    end
  end

  private

  def load_rankings_page
    load_consensus_rankings
    load_row_facts
    build_shortlist
    load_gameweek_data
    load_forecast_time
    load_players
    set_available_filters
    build_page_title
  end

  # An old-style address, or a name that has since changed. Either way there is
  # one address for him, and a card asked for is still a card when it arrives.
  def redirect_to_canonical_player
    return false if params[:id] == @player.to_param

    redirect_to player_path(@player, format: params[:format]), status: :moved_permanently
    true
  end

  def load_player
    @next_gameweek = Gameweek.next_gameweek
    @horizon = Horizon.find(params[:horizon]).key
    @card_path = player_path(@player, format: :png)
    load_player_forecast
  end

  # The rest of the page, which a card has no use for.
  def load_player_page
    load_player_performances
    load_upcoming_fixtures
    @related = RelatedComparisons.call(players: @player, gameweek: @next_gameweek, horizon: @horizon)
  end

  def load_player_forecast
    return unless @next_gameweek

    forecast = @player.forecasts.where(horizon: @horizon).includes(:gameweek).find_by(gameweek: @next_gameweek)
    return unless forecast

    @forecast_at = forecast.updated_at
    @forecast = forecast_summary(forecast)
    @player_ranking = player_ranking(forecast)
    @player_facts = latest_snapshot_stats([ @player.id ], ROW_FACT_TYPES)[@player.id]
  end

  def forecast_summary(forecast)
    {
      rank: forecast.rank,
      score: forecast.score,
      grade: TierCalculator.grade_from_points(graded_score(forecast)),
      tier: TierCalculator.tier_from_points(graded_score(forecast)),
      horizon: @horizon,
      gameweek: @next_gameweek.fpl_id
    }
  end

  def player_ranking(forecast)
    ConsensusRanking::Ranking.new(
      player_id: @player.id, name: @player.short_name, team_id: @player.team_id,
      position: @player.position, bot_rank: forecast.rank, score: forecast.score,
      tier: TierCalculator.tier_from_points(graded_score(forecast)),
      grade: TierCalculator.grade_from_points(graded_score(forecast))
    )
  end

  # A whole-season score spans many gameweeks; it is averaged back to a single
  # week before it meets the grade bands, so a season grade reads on the same
  # scale as a weekly one.
  def graded_score(forecast)
    return unless forecast.score

    forecast.score / season_divisor
  end

  def season_divisor
    Horizon.find(@horizon).divisor
  end

  def load_player_performances
    performances = @player.performances.includes(:gameweek).joins(:gameweek)
                          .order("gameweeks.fpl_id DESC").limit(5)
    @recent_rows = recent_rows(performances)
  end

  def recent_rows(performances)
    return [] if performances.empty? || @player.team.nil?

    matches = Match.includes(:home_team, :away_team)
                   .where(gameweek_id: performances.map(&:gameweek_id))
                   .where("home_team_id = :t OR away_team_id = :t", t: @player.team_id)
                   .index_by(&:gameweek_id)
    performances.map { |perf| fixture_row(perf.gameweek, matches[perf.gameweek_id], perf.gameweek_score, false) }
  end

  def load_upcoming_fixtures
    return unless @player.team

    @upcoming_rows = project_fixtures(upcoming_matches)
  end

  def upcoming_matches
    Match.includes(:home_team, :away_team, :gameweek).joins(:gameweek)
         .where("home_team_id = :team OR away_team_id = :team", team: @player.team_id)
         .where("gameweeks.fpl_id >= ?", @next_gameweek&.fpl_id || 0)
         .order("gameweeks.fpl_id ASC").limit(5).to_a
  end

  # The week's own forecast anchors the run of fixtures, and the season's stands
  # behind it for a player whose team is not playing this week. See
  # FixtureProjection#base.
  def project_fixtures(matches)
    FixtureProjection.call(
      player: @player, matches: matches, anchors: anchors,
      next_gameweek_id: @next_gameweek&.id
    ).map { |row| fixture_row(row.match.gameweek, row.match, row.points, row.projected) }
  end

  def anchors
    return [] unless @next_gameweek

    forecasts = @player.forecasts.where(gameweek: @next_gameweek).index_by(&:horizon)
    [ forecasts["gameweek"], forecasts[SEASON] ]
  end

  def fixture_row(gameweek, match, points, projected)
    home = match && match.home_team_id == @player.team_id
    {
      gameweek: gameweek,
      opponent: match && (home ? match.away_team : match.home_team),
      home: home,
      points: points,
      projected: projected
    }
  end

  def find_player_from_param
    param = params[:id].to_s

    # If param is just a number, it's an old-style database ID
    if param.match?(/\A\d+\z/)
      return Player.includes(:team).find(param)
    end

    # Otherwise, extract fpl_id from the end of the slug
    fpl_id = param.split("-").last
    Player.includes(:team).find_by!(fpl_id: fpl_id)
  end

  def redirect_to_clean_url
    return false if turbo_frame_request?
    return false unless request.path == rankings_path && params[:gameweek].present?

    redirect_to build_clean_url, status: :moved_permanently
    true
  end

  def build_clean_url
    position_rankings_path(params[:gameweek], resolve_position(params[:position]),
                  **params.permit(:team_id, :min_price, :max_price).to_h.compact_blank.symbolize_keys)
  end

  # Where a horizon lives. The season has a page of its own; a week is named by
  # its number.
  def position_rankings_path(segment, position, **extra)
    case segment.to_s
    when Horizon::SEASON then season_position_path(position: "#{position}s", **extra)
    when Horizon::UPCOMING then upcoming_position_path(position: "#{position}s", **extra)
    else gameweek_position_path(gameweek: segment, position: "#{position}s", **extra)
    end
  end

  def set_filters
    set_horizon
    @position_filter = resolve_position(params[:position])
    @team_filter = params[:team_id].present? ? params[:team_id].to_i : nil
    @min_price = price_param(params[:min_price])
    @max_price = price_param(params[:max_price])
  end

  def price_param(value)
    return if value.blank?

    (value.to_f * TENTHS_PER_MILLION).round
  end

  # Every horizon but the coming week is anchored to the next gameweek: their rows
  # are stored against it, and validation and titling resolve a real gameweek from it.
  def set_horizon
    @horizon = horizon.key
    @gameweek = horizon.gameweek? ? requested_gameweek : next_gameweek&.fpl_id
  end

  # A route says which horizon it is in the parameter it defaults; the toggle says it
  # in the one it submits. Anything else is a gameweek number, or a stranger's guess
  # at a horizon, and both resolve to the coming week.
  def horizon
    @horizon_read ||= Horizon.find(params[:horizon].presence || params[:gameweek])
  end

  def requested_gameweek
    params[:gameweek].present? ? params[:gameweek].to_i : current_gameweek
  end

  def season?
    horizon.season?
  end

  def resolve_position(param)
    POSITION_SINGULARS[param] || param || "forward"
  end

  def validate_gameweek
    return true if Gameweek.exists?(fpl_id: @gameweek)

    redirect_to rankings_path(gameweek: next_gameweek&.fpl_id || 1, position: @position_filter, team_id: @team_filter,
                             min_price: params[:min_price], max_price: params[:max_price]),
                alert: "Gameweek #{@gameweek} not found"
    false
  end

  def load_consensus_rankings
    rankings = ConsensusRanking.call(@gameweek, @position_filter, nil, horizon: @horizon)
    @consensus_rankings = TierCalculator.call(rankings, position: @position_filter, points_divisor: tier_divisor)
    @tier_groups = @consensus_rankings.group_by(&:tier)
  end

  # A season total is read as its per-gameweek average, so it meets the same tier
  # bands a single week does.
  def tier_divisor
    horizon.divisor
  end

  # When the numbers on the page were worked out. They are rewritten on the hour
  # as FPL's own data moves, and a transfer can shift a player a dozen places
  # between one reading and the next, so the page says which reading this is.
  def load_forecast_time
    @forecast_at = Forecast.where(gameweek: @gameweek_record, horizon: @horizon).maximum(:updated_at)
  end

  def load_gameweek_data
    @gameweek_record = Gameweek.find_by(fpl_id: @gameweek)
    @matches_by_team = @gameweek_record ? Match.by_team(@gameweek_record) : {}
  end

  # Shown beside a player's name but never scored: what he costs, and how many
  # managers already own him. An expensive or popular player should still top the
  # table if he deserves to, with both facts there for you to judge.
  def load_row_facts
    @row_facts = latest_snapshot_stats(@consensus_rankings.map(&:player_id), ROW_FACT_TYPES)
    set_price_bounds
  end

  def set_price_bounds
    costs = @row_facts.values.filter_map { |facts| facts["now_cost"] }
    return if costs.empty?

    floor = (costs.min / PRICE_STEP).floor * PRICE_STEP
    ceil = (costs.max / PRICE_STEP).ceil * PRICE_STEP
    clamp_price_band(floor, ceil)
    @price_filter = price_filter_view(floor, ceil)
  end

  def clamp_price_band(floor, ceil)
    @min_price = @min_price&.clamp(floor, ceil)
    @max_price = @max_price&.clamp(floor, ceil)
  end

  def price_filter_view(floor, ceil)
    {
      floor: to_millions(floor),
      ceil: to_millions(ceil),
      min: to_millions(@min_price || floor),
      max: to_millions(@max_price || ceil),
      step: to_millions(PRICE_STEP)
    }
  end

  def to_millions(tenths)
    tenths / TENTHS_PER_MILLION.to_f
  end

  # Who is worth putting in front of somebody this week.
  #
  # A player who cannot score is not a choice: no game, ruled out injured or
  # suspended, or nothing behind him we can read. The forecast already says so by
  # coming out at nought, because availability and fixtures multiply through it,
  # so one test covers all three.
  #
  # Then the list is cut to a readable depth. Nothing is filtered on popularity: a
  # player with a real record and a real fixture is a legitimate pick at any
  # ownership, and the crowd already pushes the unfancied ones down the order
  # without needing them removed from it.
  #
  # Ranks are renumbered afterwards so the page reads 1, 2, 3.
  def build_shortlist
    field = @consensus_rankings.select { |ranking| ranking.score.to_f.positive? }
                               .first(RANKING_DEPTH.fetch(@position_filter, 100))
    field.each_with_index { |ranking, index| ranking.bot_rank = index + 1 }
    @consensus_rankings = field.select { |ranking| within_filters?(ranking) }
    @tier_groups = @consensus_rankings.group_by(&:tier)
  end

  def within_filters?(ranking)
    matches_team?(ranking) && priced_within_band?(ranking.player_id)
  end

  def matches_team?(ranking)
    @team_filter.nil? || ranking.team_id == @team_filter
  end

  def priced_within_band?(player_id)
    return true if @min_price.nil? && @max_price.nil?

    cost = @row_facts.dig(player_id, "now_cost")
    return false if cost.nil?
    return false if @min_price && cost < @min_price
    return false if @max_price && cost > @max_price

    true
  end

  def latest_snapshot_stats(player_ids, types)
    Statistic.where(player_id: player_ids, type: types).latest_by_player
  end

  def load_players
    @players = Player.includes(:team)
                     .joins("LEFT JOIN performances ON performances.player_id = players.id")
                     .where(position: @position_filter)
                     .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                     .group("players.id")
                     .order("total_score_cached DESC, first_name, last_name")
    @players_by_id = @players.index_by(&:id)
  end

  def set_available_filters
    @horizon_options = horizon_options
    @available_positions = %w[goalkeeper defender midfielder forward]
    @available_teams = Team.order(:name).select(:id, :name, :short_name)
  end

  # Two horizons, not a growing list of gameweeks: the coming week, or all that
  # remain.
  def horizon_options
    options = []
    options << [ "Next Gameweek", next_gameweek.fpl_id ] if next_gameweek
    options << [ "Rest of Season", SEASON ]
    options
  end

  # What this horizon is called in an address: a gameweek by its number, the rest by
  # their own name.
  def horizon_param
    horizon.gameweek? ? @gameweek : horizon.key
  end

  # This same page read at the other horizon. Changing horizon is not a reason to
  # forget the team and the prices you already chose, so those travel with it.
  def horizon_url(which)
    segment = which.to_s == Horizon::GAMEWEEK ? @gameweek : which.to_s
    position_rankings_path(segment, @position_filter, **retained_filters)
  end

  def retained_filters
    { team_id: @team_filter, min_price: params[:min_price], max_price: params[:max_price] }.compact_blank
  end

  # The four positions, as the same control the horizon uses. The team survives a
  # change of position but the price does not: what a keeper costs and what a
  # forward costs are different ranges, so carrying one over hides half the list.
  # Named in full where there is room, because "Goalkeepers" is the word people
  # search for and the word the page itself is titled with. GK on a phone, where
  # four full names across a row would wrap to three lines.
  def position_options
    @available_positions.map do |position|
      SegmentedControlComponent::Option.new(
        label: position.pluralize.capitalize,
        short_label: FantasyForecast::POSITION_CONFIG.dig(position, :display_name),
        url: position_rankings_path(horizon_param, position, **{ team_id: @team_filter }.compact_blank),
        current: @position_filter == position
      )
    end
  end

  def horizon_label
    horizon.label(gameweek: @gameweek)
  end

  # A title tag wants the week as GW1 and the others in full: there is room for "Rest
  # of Season" in a title and none for it in a toggle, which is why the short name the
  # control uses is not the short name a title wants.
  def horizon_short
    horizon.gameweek? ? horizon.short_label(gameweek: @gameweek) : horizon.label
  end

  # The heading and the title tag say the same thing, in the words somebody would
  # have typed to arrive here. They used to disagree: "Best FPL Defenders GW1" in the
  # tab, "Player Rankings - Gameweek 1 Defenders" on the page.
  def build_page_title
    @page_title = "Best FPL #{@position_filter.to_s.capitalize}s, #{horizon_label}"
    @page_title += " · #{Team.find_by(id: @team_filter)&.name}" if @team_filter
    @canonical_path = canonical_path
    @card_path = position_rankings_path(horizon_param, @position_filter, format: :png)
  end

  # A card is drawn from the forecast and nothing else, so the reading it was
  # drawn from is the whole of its name. A fresh forecast is a fresh card.
  def rankings_card_key
    [ "rankings_card", @position_filter, horizon_param, @forecast_at&.to_i ].join("/")
  end

  def player_card_key
    [ "player_card", @player.to_param, @horizon, @forecast_at&.to_i ].join("/")
  end

  # The rankings page stands for itself.
  #
  # It used to name the coming gameweek's page as its canonical, which handed a
  # strong address to one that goes stale the week it is played: every week it
  # pointed somewhere new, and every page it had pointed at was left behind. A
  # filtered view of the rankings still answers to the rankings, which is what a
  # canonical is for.
  def canonical_path
    rankings_home? ? rankings_path : position_rankings_path(horizon_param, @position_filter)
  end

  def rankings_home?
    request.path == rankings_path && @position_filter == "forward"
  end

  def next_gameweek
    @next_gameweek ||= Gameweek.next_gameweek
  end

  def current_gameweek
    next_gameweek&.fpl_id || Gameweek.current_gameweek&.fpl_id || available_gameweeks_with_forecasts.first || 1
  end

  def available_gameweeks_with_forecasts
    @available_gameweeks_with_forecasts ||= Gameweek.with_forecasts.order(fpl_id: :desc).pluck(:fpl_id)
  end
end
