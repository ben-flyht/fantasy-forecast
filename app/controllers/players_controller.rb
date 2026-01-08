class PlayersController < ApplicationController
  before_action :set_filters, only: [ :index ]

  def index
    return unless validate_gameweek

    load_consensus_rankings
    load_gameweek_data
    load_players
    set_available_filters
    build_page_title
  end

  private

  def set_filters
    @gameweek = params[:gameweek].present? ? params[:gameweek].to_i : current_gameweek
    @position_filter = params[:position] || "forward"
    @team_filter = params[:team_id].present? ? params[:team_id].to_i : nil
  end

  def validate_gameweek
    return true if Gameweek.exists?(fpl_id: @gameweek)

    redirect_to root_path(gameweek: next_gameweek&.fpl_id || 1, position: @position_filter, team_id: @team_filter),
                alert: "Gameweek #{@gameweek} not found"
    false
  end

  def load_consensus_rankings
    rankings = ConsensusRanking.for_week_and_position(@gameweek, @position_filter, @team_filter)
    @consensus_rankings = TierCalculator.new(rankings, position: @position_filter).call
    @tier_groups = @consensus_rankings.group_by(&:tier)
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
    @available_gameweeks = available_gameweeks_with_forecasts
    @available_positions = %w[goalkeeper defender midfielder forward]
    @available_teams = Team.order(:name).select(:id, :name, :short_name)
  end

  def build_page_title
    @page_title = "Player Rankings - Gameweek #{@gameweek}"
    @page_title += " #{@position_filter.capitalize}s" if @position_filter.present?
    @page_title += " - #{Team.find_by(id: @team_filter)&.name}" if @team_filter
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
