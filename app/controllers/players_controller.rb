class PlayersController < ApplicationController
  # Facts about a player we report rather than rate. See #load_row_facts.
  ROW_FACT_TYPES = %w[now_cost selected_by_percent transfers_in transfers_out].freeze

  # How deep a list is worth reading in each position. Past this you are scrolling
  # through players nobody is choosing between, and the tail is where a forecast is
  # least reliable anyway: those are the players whose minutes we are guessing at.
  RANKING_DEPTH = {
    "goalkeeper" => 50, "defender" => 100, "midfielder" => 100, "forward" => 50
  }.freeze

  # The horizon that spans every gameweek that remains, as the routes and the
  # stored forecasts both spell it.
  SEASON = "season".freeze

  POSITION_SINGULARS = {
    "goalkeepers" => "goalkeeper", "defenders" => "defender",
    "midfielders" => "midfielder", "forwards" => "forward"
  }.freeze

  before_action :set_filters, only: [ :index ]

  helper_method :season?, :horizon_label, :horizon_short, :horizon_param, :rankings_path

  def index
    return if redirect_to_clean_url
    return unless validate_gameweek

    load_rankings_page
  end

  def show
    @player = find_player_from_param

    # Redirect to canonical URL if accessed via old-style or incorrect slug
    unless params[:id] == @player.to_param
      redirect_to player_path(@player), status: :moved_permanently
      return
    end

    @next_gameweek = Gameweek.next_gameweek
    load_player_forecast
    load_player_performances
    load_upcoming_fixture
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

  def load_player_forecast
    return unless @next_gameweek

    forecast = @player.forecasts.weekly.includes(:gameweek).find_by(gameweek: @next_gameweek)
    return unless forecast

    @forecast = forecast_summary(forecast)
    @player_ranking = player_ranking(forecast)
    @player_facts = latest_snapshot_stats([ @player.id ], ROW_FACT_TYPES)[@player.id]
  end

  def forecast_summary(forecast)
    {
      rank: forecast.rank,
      score: forecast.score,
      grade: TierCalculator.grade_from_points(forecast.score),
      gameweek: @next_gameweek.fpl_id,
      tier: TierCalculator.calculate_player_tier(forecast, @player.position),
      working: forecast.working
    }
  end

  def player_ranking(forecast)
    ConsensusRanking::Ranking.new(
      player_id: @player.id, name: @player.short_name, team_id: @player.team_id,
      position: @player.position, bot_rank: forecast.rank, score: forecast.score,
      tier: TierCalculator.tier_from_points(forecast.score),
      grade: TierCalculator.grade_from_points(forecast.score)
    )
  end

  def load_player_performances
    @performances = @player.performances
                           .includes(:gameweek)
                           .joins(:gameweek)
                           .order("gameweeks.fpl_id DESC")
                           .limit(8)
    @total_score = @player.total_score
    @form_scores = expand_per_match_scores(@performances, build_match_counts_for(@performances)).first(8)
  end

  def load_upcoming_fixture
    return unless @next_gameweek && @player.team

    @upcoming_matches = Match.includes(:home_team, :away_team)
                             .where(gameweek: @next_gameweek)
                             .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)
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
    return false unless request.path == "/" && params[:gameweek].present?

    redirect_to build_clean_url, status: :moved_permanently
    true
  end

  def build_clean_url
    rankings_path(params[:gameweek], resolve_position(params[:position]),
                  **params.permit(:team_id).to_h.compact_blank.symbolize_keys)
  end

  # Where a horizon lives. The season has a page of its own; a week is named by
  # its number.
  def rankings_path(horizon, position, **extra)
    if horizon == SEASON
      season_position_path(position: "#{position}s", **extra)
    else
      gameweek_position_path(gameweek: horizon, position: "#{position}s", **extra)
    end
  end

  def set_filters
    set_horizon
    @position_filter = resolve_position(params[:position])
    @team_filter = params[:team_id].present? ? params[:team_id].to_i : nil
  end

  # The season horizon is anchored to the next gameweek: its rows are stored
  # against that week, and validation and titling resolve a real gameweek from it.
  def set_horizon
    if season_requested?
      @horizon = SEASON
      @gameweek = next_gameweek&.fpl_id
    else
      @horizon = "gameweek"
      @gameweek = params[:gameweek].present? ? params[:gameweek].to_i : current_gameweek
    end
  end

  # The season page says so in its route; the horizon dropdown says so in the
  # parameter it submits, on its way to that page.
  def season_requested?
    params[:horizon] == SEASON || params[:gameweek] == SEASON
  end

  def season?
    @horizon == SEASON
  end

  def resolve_position(param)
    POSITION_SINGULARS[param] || param || "forward"
  end

  def validate_gameweek
    return true if Gameweek.exists?(fpl_id: @gameweek)

    redirect_to root_path(gameweek: next_gameweek&.fpl_id || 1, position: @position_filter, team_id: @team_filter),
                alert: "Gameweek #{@gameweek} not found"
    false
  end

  def load_consensus_rankings
    rankings = ConsensusRanking.call(@gameweek, @position_filter, @team_filter, horizon: @horizon)
    @consensus_rankings = TierCalculator.call(rankings, position: @position_filter, points_divisor: tier_divisor)
    @tier_groups = @consensus_rankings.group_by(&:tier)
  end

  # A season total is read as its per-gameweek average, so it meets the same tier
  # bands a single week does.
  def tier_divisor
    season? ? [ Gameweek.remaining.count, 1 ].max : 1
  end

  # When the numbers on the page were worked out. They are rewritten on the hour
  # as FPL's own data moves, and a transfer can shift a player a dozen places
  # between one reading and the next, so the page says which reading this is.
  def load_forecast_time
    @forecast_at = Forecast.where(gameweek: @gameweek_record, horizon: @horizon).maximum(:updated_at)
  end

  def load_gameweek_data
    @gameweek_record = Gameweek.find_by(fpl_id: @gameweek)
    @matches_by_team = @gameweek_record ? build_matches_by_team : {}
  end

  def build_matches_by_team
    matches = Hash.new { |h, k| h[k] = [] }
    Match.includes(:home_team, :away_team).where(gameweek: @gameweek_record).each do |match|
      matches[match.home_team_id] << match
      matches[match.away_team_id] << match
    end
    matches
  end

  # Shown beside a player's name but never scored: what he costs, and how many
  # managers already own him. An expensive or popular player should still top the
  # table if he deserves to, with both facts there for you to judge.
  def load_row_facts
    @row_facts = latest_snapshot_stats(@consensus_rankings.map(&:player_id), ROW_FACT_TYPES)
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
    @consensus_rankings = @consensus_rankings.select { |ranking| ranking.score.to_f.positive? }
                                             .first(RANKING_DEPTH.fetch(@position_filter, 100))
    @consensus_rankings.each_with_index { |ranking, index| ranking.bot_rank = index + 1 }
    @tier_groups = @consensus_rankings.group_by(&:tier)
  end

  def latest_snapshot_stats(player_ids, types)
    stats = Hash.new { |hash, key| hash[key] = {} }
    Statistic.where(player_id: player_ids, type: types)
             .order(:gameweek_id)
             .pluck(:player_id, :type, :value)
             .each { |player_id, type, value| stats[player_id][type] = value.to_f }
    stats
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

  def horizon_param
    season? ? SEASON : @gameweek
  end

  def horizon_label
    season? ? "Rest of Season" : "Gameweek #{@gameweek}"
  end

  def horizon_short
    season? ? "Rest of Season" : "GW#{@gameweek}"
  end

  def build_page_title
    @page_title = "Player Rankings - #{horizon_label}"
    @page_title += " #{@position_filter.capitalize}s" if @position_filter.present?
    @page_title += " - #{Team.find_by(id: @team_filter)&.name}" if @team_filter
    @canonical_path = rankings_path(horizon_param, @position_filter)
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

  def build_match_counts_for(performances)
    team_ids = performances.map(&:team_id).uniq
    gameweek_ids = performances.map(&:gameweek_id).uniq

    count_matches(team_ids, gameweek_ids)
  end

  def count_matches(team_ids, gameweek_ids)
    counts = Hash.new(0)
    Match.where(gameweek_id: gameweek_ids)
         .where("home_team_id IN (?) OR away_team_id IN (?)", team_ids, team_ids)
         .pluck(:home_team_id, :away_team_id, :gameweek_id)
         .each do |home_id, away_id, gw_id|
      counts[[ home_id, gw_id ]] += 1
      counts[[ away_id, gw_id ]] += 1
    end
    counts
  end

  def expand_per_match_scores(performances, match_counts)
    performances.flat_map do |perf|
      count = [ match_counts[[ perf.team_id, perf.gameweek_id ]], 1 ].max
      per_match = (perf.gameweek_score.to_f / count).round
      Array.new(count, per_match)
    end
  end
end
