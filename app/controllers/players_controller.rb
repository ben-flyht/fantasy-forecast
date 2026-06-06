class PlayersController < ApplicationController
  POSITION_SINGULARS = {
    "goalkeepers" => "goalkeeper", "defenders" => "defender",
    "midfielders" => "midfielder", "forwards" => "forward"
  }.freeze

  before_action :set_filters, only: [ :index ]

  def index
    return if redirect_to_clean_url
    return unless validate_gameweek

    load_consensus_rankings
    load_gameweek_data
    load_players
    load_recent_performances
    set_available_filters
    load_draft_availability
    build_page_title
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

  def load_player_forecast
    return unless @next_gameweek

    forecast = @player.forecasts.includes(:gameweek).find_by(gameweek: @next_gameweek)
    return unless forecast

    @forecast = {
      rank: forecast.rank,
      score: forecast.score,
      explanation: forecast.explanation,
      gameweek: @next_gameweek.fpl_id,
      tier: TierCalculator.calculate_player_tier(forecast, @player.position)
    }
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
    position = resolve_position(params[:position])
    extra = params.permit(:team_id, :draft_team).to_h.compact_blank
    gameweek_position_path(gameweek: params[:gameweek], position: "#{position}s", **extra)
  end

  def set_filters
    @gameweek = params[:gameweek].present? ? params[:gameweek].to_i : current_gameweek
    @position_filter = resolve_position(params[:position])
    @team_filter = params[:team_id].present? ? params[:team_id].to_i : nil
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
    rankings = ConsensusRanking.for_week_and_position(@gameweek, @position_filter, @team_filter)
    top_score = position_top_score
    @consensus_rankings = TierCalculator.new(rankings, position: @position_filter, top_score: top_score).call
    @tier_groups = @consensus_rankings.group_by(&:tier)
  end

  def position_top_score
    all_rankings = ConsensusRanking.for_week_and_position(@gameweek, @position_filter, nil)
    all_rankings.select { |r| r.score.present? && r.score.positive? }.map(&:score).max || 0
  end

  def load_gameweek_data
    @gameweek_record = Gameweek.find_by(fpl_id: @gameweek)
    @matches_by_team = @gameweek_record ? build_matches_by_team : {}
  end

  def load_recent_performances
    player_ids = @consensus_rankings.map(&:player_id)
    performances = Performance.joins(:gameweek)
                              .where(player_id: player_ids)
                              .order("gameweeks.fpl_id DESC")
                              .select(:player_id, :gameweek_score, :team_id, :gameweek_id)

    match_counts = build_match_counts_for(performances)

    @performances_by_player = performances.group_by(&:player_id).transform_values do |perfs|
      expand_per_match_scores(perfs, match_counts).first(8)
    end
  end

  def build_matches_by_team
    matches = Hash.new { |h, k| h[k] = [] }
    Match.includes(:home_team, :away_team).where(gameweek: @gameweek_record).each do |match|
      matches[match.home_team_id] << match
      matches[match.away_team_id] << match
    end
    matches
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

  def load_draft_availability
    @draft_entry_id = cookies[:draft_entry_id]
    league_id = cookies[:draft_league_id]
    return unless @draft_entry_id.present? && league_id.present?

    league_info = Fpl::DraftLeagueStatus.league_info(league_id, @draft_entry_id)
    @draft_team_name = league_info[:mine]
    @draft_league_entries = league_info[:opponents]
    @selected_draft_team = params[:draft_team].presence || league_info[:next_opponent_id]
    @draft_player_categories = Fpl::DraftLeagueStatus.call(
      @draft_entry_id, league_id, selected_entry_id: @selected_draft_team
    )
  end

  def set_available_filters
    @available_gameweeks = available_gameweeks_with_forecasts
    @available_positions = %w[goalkeeper defender midfielder forward]
    @available_teams = Team.order(:name).select(:id, :name, :short_name)
  end

  def build_page_title
    @page_title = "Player Rankings - Gameweek #{@gameweek}"
    @page_title += " #{@position_filter.capitalize}s" if @position_filter.present?
    @page_title += " - #{Team.find_by(id: @team_filter)&.name}" if @team_filter
    @canonical_path = gameweek_position_path(gameweek: @gameweek, position: "#{@position_filter}s")
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
