class PlayersController < ApplicationController
  before_action :authenticate_user!, only: [ :toggle_forecast ]
  before_action :set_filters, only: [ :index ]

  def index
    return unless validate_gameweek

    load_consensus_rankings
    load_gameweek_data
    load_players
    load_user_forecasts
    set_available_filters
    build_page_title
  end

  def toggle_forecast
    return render_forbidden("Please confirm your email address before making forecasts") unless current_user.confirmed?
    return render_error("No next gameweek available") unless next_gameweek

    selected = process_forecast_toggle
    return if performed?

    render_forecast_response(selected)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  end

  private

  def set_filters
    @gameweek = params[:gameweek].present? ? params[:gameweek].to_i : current_gameweek
    @position_filter = params[:position] || "forward"
    @team_filter = params[:team_id].present? ? params[:team_id].to_i : nil
  end

  def validate_gameweek
    return true if Gameweek.exists?(fpl_id: @gameweek)

    redirect_to players_path(gameweek: next_gameweek&.fpl_id || 1, position: @position_filter, team_id: @team_filter),
                alert: "Gameweek #{@gameweek} not found"
    false
  end

  def load_consensus_rankings
    @consensus_rankings = ConsensusRanking.for_week_and_position(@gameweek, @position_filter, @team_filter)
  end

  def load_gameweek_data
    @gameweek_record = Gameweek.find_by(fpl_id: @gameweek)

    if @gameweek_record
      @total_forecasters = count_forecasters
      @matches_by_team = build_matches_by_team
    else
      @total_forecasters = 0
      @matches_by_team = {}
    end
  end

  def count_forecasters
    Forecast.joins(:gameweek)
            .where(gameweeks: { fpl_id: @gameweek })
            .distinct
            .count(:user_id)
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

  def load_user_forecasts
    if user_signed_in? && @gameweek_record
      @current_forecasts = current_user.forecasts.includes(:player).where(gameweek: @gameweek_record).index_by(&:player_id)
      @forecast_counts = current_user.forecasts.joins(:player).where(gameweek: @gameweek_record).group("players.position").count
      @is_next_gameweek = next_gameweek && @gameweek == next_gameweek.fpl_id
    else
      @current_forecasts = {}
      @forecast_counts = {}
      @is_next_gameweek = false
    end
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
  end

  def process_forecast_toggle
    player = Player.find(params[:player_id])
    existing_forecast = current_user.forecasts.find_by(gameweek: next_gameweek, player_id: player.id)

    if existing_forecast
      existing_forecast.destroy
      false
    else
      create_forecast_for_player(player)
    end
  end

  def create_forecast_for_player(player)
    return if position_limit_reached?(player)

    current_user.forecasts.create!(gameweek: next_gameweek, player_id: player.id)
    true
  end

  def position_limit_reached?(player)
    config = FantasyForecast::POSITION_CONFIG[player.position]
    count = current_user.forecasts.joins(:player).where(gameweek: next_gameweek, players: { position: player.position }).count

    return false if count < config[:slots]

    render_error("Maximum #{config[:slots]} #{config[:display_name]} selections reached")
    true
  end

  def render_forecast_response(selected)
    forecast_counts = current_user.forecasts.joins(:player).where(gameweek: next_gameweek).group("players.position").count
    render json: { success: true, selected: selected, forecast_counts: forecast_counts }
  end

  def render_forbidden(message)
    render json: { error: message }, status: :forbidden
  end

  def render_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end

  def next_gameweek
    @next_gameweek ||= Gameweek.next_gameweek
  end

  def current_gameweek
    next_gameweek&.fpl_id || Gameweek.current_gameweek&.fpl_id || 1
  end

  def available_gameweeks_with_forecasts
    starting_gw = Gameweek::STARTING_GAMEWEEK
    return [ starting_gw ] unless next_gameweek

    (starting_gw..next_gameweek.fpl_id).to_a.reverse
  end
end
