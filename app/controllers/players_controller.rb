class PlayersController < ApplicationController
  before_action :authenticate_user!, only: [ :toggle_forecast ]

  def index
    @gameweek = params[:gameweek].present? ? params[:gameweek].to_i : current_gameweek
    @position_filter = params[:position] || "forward"  # Default to forward if no position specified
    @team_filter = params[:team_id].present? ? params[:team_id].to_i : nil

    # Check if gameweek exists
    next_gw = Gameweek.next_gameweek
    gameweek_exists = Gameweek.exists?(fpl_id: @gameweek)

    unless gameweek_exists
      redirect_to players_path(gameweek: next_gw&.fpl_id || 1, position: @position_filter, team_id: @team_filter), alert: "Gameweek #{@gameweek} not found"
      return
    end

    # Get consensus scores for the gameweek with position and team filtering
    @consensus_rankings = ConsensusRanking.for_week_and_position(@gameweek, @position_filter, @team_filter)

    # Get total number of unique forecasters for this gameweek
    @gameweek_record = Gameweek.find_by(fpl_id: @gameweek)
    if @gameweek_record
      @total_forecasters = Forecast.joins(:gameweek)
                                   .where(gameweeks: { fpl_id: @gameweek })
                                   .distinct
                                   .count(:user_id)

      # Preload matches for opponent component to avoid N+1
      @matches_by_team = Hash.new { |h, k| h[k] = [] }
      Match.includes(:home_team, :away_team)
           .where(gameweek: @gameweek_record)
           .each do |match|
        @matches_by_team[match.home_team_id] << match
        @matches_by_team[match.away_team_id] << match
      end
    else
      @total_forecasters = 0
      @matches_by_team = {}
    end

    # Load all players for the current position with their scores
    players_with_scores = Player.includes(:team)
                                .joins("LEFT JOIN performances ON performances.player_id = players.id")
                                .where(position: @position_filter)
                                .select("players.*, COALESCE(SUM(performances.gameweek_score), 0) AS total_score_cached")
                                .group("players.id")
                                .order("total_score_cached DESC, first_name, last_name")
    @players = players_with_scores
    @players_by_id = @players.index_by(&:id)

    # Get current user's forecasts
    if user_signed_in?
      next_gw = Gameweek.next_gameweek

      # Load user's forecasts for the current viewing gameweek
      if @gameweek_record
        @current_forecasts = current_user.forecasts
                    .includes(:player)
                    .where(gameweek: @gameweek_record)
                    .index_by(&:player_id)

        # Get forecast counts for the current viewing gameweek
        @forecast_counts = current_user.forecasts
                    .joins(:player)
                    .where(gameweek: @gameweek_record)
                    .group("players.position")
                    .count
      else
        @current_forecasts = {}
        @forecast_counts = {}
      end

      # Check if viewing the next gameweek (to show selection UI)
      @is_next_gameweek = next_gw && @gameweek == next_gw.fpl_id
    else
      @current_forecasts = {}
      @forecast_counts = {}
      @is_next_gameweek = false
    end

    @available_gameweeks = available_gameweeks_with_forecasts
    @available_positions = [ "goalkeeper", "defender", "midfielder", "forward" ]
    @available_teams = Team.order(:name).select(:id, :name, :short_name)

    @page_title = "Player Rankings - Gameweek #{@gameweek}"
    @page_title += " (#{@position_filter.capitalize}s)" if @position_filter.present?
    if @team_filter
      team = Team.find_by(id: @team_filter)
      @page_title += " - #{team.name}" if team
    end
  end

  def toggle_forecast
    unless current_user.confirmed?
      render json: { error: "Please confirm your email address before making forecasts" }, status: :forbidden
      return
    end

    next_gw = Gameweek.next_gameweek
    player = Player.find(params[:player_id])

    unless next_gw
      render json: { error: "No next gameweek available" }, status: :unprocessable_entity
      return
    end

    # Check if forecast already exists
    existing_forecast = current_user.forecasts.find_by(
      gameweek: next_gw,
      player_id: player.id
    )

    if existing_forecast
      # Unselect: destroy the forecast
      existing_forecast.destroy
      selected = false
    else
      # Select: check position limits first
      position_config = FantasyForecast::POSITION_CONFIG[player.position]
      max_slots = position_config[:slots]

      current_count = current_user.forecasts
                                  .joins(:player)
                                  .where(gameweek: next_gw, players: { position: player.position })
                                  .count

      if current_count >= max_slots
        render json: {
          error: "Maximum #{max_slots} #{position_config[:display_name]} selections reached"
        }, status: :unprocessable_entity
        return
      end

      # Create new forecast
      current_user.forecasts.create!(
        gameweek: next_gw,
        player_id: player.id
      )
      selected = true
    end

    # Return updated counts
    forecast_counts = current_user.forecasts
                                  .joins(:player)
                                  .where(gameweek: next_gw)
                                  .group("players.position")
                                  .count

    render json: {
      success: true,
      selected: selected,
      forecast_counts: forecast_counts
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_entity
  end

  private

  def current_gameweek
    # Use the next gameweek (what we're forecasting for), fallback to current if no next, then 1
    Gameweek.next_gameweek&.fpl_id || Gameweek.current_gameweek&.fpl_id || 1
  end

  def available_gameweeks_with_forecasts
    next_gw = Gameweek.next_gameweek
    starting_gw = Gameweek::STARTING_GAMEWEEK

    if next_gw
      # Show all gameweeks from starting gameweek to next gameweek
      (starting_gw..next_gw.fpl_id).to_a.reverse
    else
      # Fallback: show starting gameweek
      [ starting_gw ]
    end
  end
end
