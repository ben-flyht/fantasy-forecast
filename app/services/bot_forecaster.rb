class BotForecaster < ApplicationService
  include StrategyScoring

  attr_reader :gameweek, :strategy_config, :strategy, :generate_explanations

  def initialize(strategy_config:, gameweek:, strategy: nil, generate_explanations: true)
    @strategy_config = strategy_config
    @gameweek = gameweek
    @strategy = strategy
    @generate_explanations = generate_explanations
  end

  def call
    validate_inputs!
    clear_existing_forecasts
    generate_all_position_forecasts
  end

  private

  def validate_inputs!
    raise ArgumentError, "No gameweek available" unless gameweek
  end

  def generate_all_position_forecasts
    FantasyForecast::POSITION_CONFIG.keys.flat_map { |position| generate_position_forecasts(position) }
  end

  def generate_position_forecasts(position)
    config = config_for_position(position)
    ranked_players = rank_all_players(position, config)
    @current_top_score = ranked_players.first&.dig(:score) || 0
    ranked_players.map { |data| create_forecast(data[:player], data[:rank], data[:score]) }
  end

  def config_for_position(position)
    strategy_config.dig(:positions, position.to_sym) || strategy_config
  end

  def rank_all_players(position, config)
    players = Player.where(position: position).includes(:statistics, :team, :performances)
    score_and_rank_players(players, config)
  end

  def score_and_rank_players(players, config)
    current_fpl_id = gameweek.fpl_id
    scored = players.map { |p| build_scored_player(p, config, current_fpl_id) }
    assign_ranks(scored)
  end

  def build_scored_player(player, config, current_fpl_id)
    { player: player, score: calculate_player_score(player, config, current_fpl_id), available: player_available?(player) }
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

  def clear_existing_forecasts
    Forecast.where(gameweek: gameweek).destroy_all
  end

  def create_forecast(player, rank, score)
    explanation = generate_explanation(player, rank, score) if generate_explanations && rank.present?
    Forecast.create!(player: player, gameweek: gameweek, strategy: strategy, rank: rank, score: score, explanation: explanation)
  end

  def generate_explanation(player, rank, score)
    config = config_for_position(player.position)

    breakdown = ScoringBreakdown.new(
      player: player,
      strategy_config: config,
      gameweek: gameweek
    ).call

    ExplanationGenerator.new(
      player: player,
      rank: rank,
      gameweek: gameweek,
      breakdown: breakdown,
      tier: calculate_tier(score)
    ).call
  rescue StandardError => e
    Rails.logger.error("Failed to generate explanation for #{player.short_name}: #{e.message}")
    nil
  end

  def calculate_tier(score)
    return 5 if score.nil? || @current_top_score.zero?

    percentage_from_top = ((@current_top_score - score) / @current_top_score.to_f) * 100

    case percentage_from_top
    when -Float::INFINITY..20 then 1
    when 20..40 then 2
    when 40..60 then 3
    when 60..80 then 4
    else 5
    end
  end
end
