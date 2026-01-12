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

  def show
    @player = Player.includes(:team).find(params[:id])
    @next_gameweek = Gameweek.next_gameweek
    load_player_forecast
    load_player_performances
    load_upcoming_fixture
    load_player_news
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
      gameweek: @next_gameweek.fpl_id
    }

    if forecast.score.present?
      @forecast[:tier] = calculate_player_tier(forecast)
    end
  end

  def calculate_player_tier(forecast)
    top_score = Forecast.where(gameweek: @next_gameweek)
                        .joins(:player)
                        .where(players: { position: @player.position })
                        .maximum(:score) || 0

    return TierCalculator.tier_info(5) if top_score.zero? || forecast.score.nil?

    percentage_from_top = ((top_score - forecast.score) / top_score.to_f) * 100

    tier_number = case percentage_from_top
                  when -Float::INFINITY..20 then 1
                  when 20..40 then 2
                  when 40..60 then 3
                  when 60..80 then 4
                  else 5
                  end

    TierCalculator.tier_info(tier_number)
  end

  def load_player_performances
    @performances = @player.performances
                           .includes(:gameweek)
                           .joins(:gameweek)
                           .order("gameweeks.fpl_id DESC")
                           .limit(5)
    @total_score = @player.total_score
  end

  def load_upcoming_fixture
    return unless @next_gameweek && @player.team

    @upcoming_match = Match.includes(:home_team, :away_team)
                           .where(gameweek: @next_gameweek)
                           .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)
                           .first
  end

  def load_player_news
    @news = GoogleNews::FetchPlayerNews.call(player: @player)
  end

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
