class PositionForecaster < ApplicationService
  include StrategyScoring

  attr_reader :gameweek, :strategy_config, :position, :strategy, :generate_explanations

  def initialize(strategy_config:, position:, gameweek:, strategy: nil, generate_explanations: true)
    @strategy_config = strategy_config
    @position = position
    @gameweek = gameweek
    @strategy = strategy
    @generate_explanations = generate_explanations
  end

  def call
    validate_inputs!
    ranked_players = rank_all_players
    @top_score = ranked_players.first&.dig(:score) || 0
    ranked_players.map { |data| create_or_update_forecast(data[:player], data[:rank], data[:score]) }
  end

  private

  def validate_inputs!
    raise ArgumentError, "No gameweek available" unless gameweek
    raise ArgumentError, "Invalid position" unless valid_position?
  end

  def valid_position?
    FantasyForecast::POSITION_CONFIG.key?(position)
  end

  def rank_all_players
    players = Player.where(position: position).includes(:statistics, :team)
    score_and_rank_players(players)
  end

  def score_and_rank_players(players)
    current_fpl_id = gameweek.fpl_id
    scored = players.map { |p| build_scored_player(p, current_fpl_id) }
    assign_ranks(scored)
  end

  def build_scored_player(player, current_fpl_id)
    { player: player, score: calculate_player_score(player, strategy_config, current_fpl_id), available: player_available?(player) }
  end

  def player_available?(player)
    chance = player.chance_of_playing(gameweek)
    chance.nil? || chance > 0
  end

  def assign_ranks(scored_players)
    available, unavailable = scored_players.partition { |p| p[:available] }
    ranked_available = rank_by_score(available)
    unranked_unavailable = sort_alphabetically(unavailable)
    ranked_available + unranked_unavailable
  end

  def rank_by_score(players)
    players.sort_by { |p| -p[:score] }.each_with_index.map { |item, i| { player: item[:player], rank: i + 1, score: item[:score] } }
  end

  def sort_alphabetically(players)
    players.sort_by { |p| p[:player].short_name.downcase }.map { |item| { player: item[:player], rank: nil, score: item[:score] } }
  end

  def create_or_update_forecast(player, rank, score)
    forecast = Forecast.find_or_initialize_by(player: player, gameweek: gameweek)
    forecast.strategy = strategy if strategy
    forecast.rank = rank
    forecast.score = score
    forecast.explanation = generate_explanation(player, rank, score) if generate_explanations && rank.present?
    forecast.save!
    forecast
  end

  def generate_explanation(player, rank, score)
    breakdown = build_breakdown(player)
    build_explanation(player, rank, breakdown, score)
  rescue StandardError => e
    Rails.logger.error("Failed to generate explanation for #{player.short_name}: #{e.message}")
    nil
  end

  def build_breakdown(player)
    ScoringBreakdown.new(player: player, strategy_config: strategy_config, gameweek: gameweek).call
  end

  def build_explanation(player, rank, breakdown, score)
    ExplanationGenerator.new(player: player, rank: rank, gameweek: gameweek, breakdown: breakdown, tier: calculate_tier(score)).call
  end

  def calculate_tier(score)
    return 5 if score.nil? || @top_score.zero?

    percentage_from_top = ((@top_score - score) / @top_score.to_f) * 100

    case percentage_from_top
    when -Float::INFINITY..20 then 1
    when 20..40 then 2
    when 40..60 then 3
    when 60..80 then 4
    else 5
    end
  end
end
