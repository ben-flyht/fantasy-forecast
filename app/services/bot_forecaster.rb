class BotForecaster < ApplicationService
  include StrategyScoring

  attr_reader :user, :gameweek, :strategy_config, :strategy

  def initialize(user:, strategy_config:, gameweek:, strategy: nil)
    @user = user
    @strategy_config = strategy_config
    @gameweek = gameweek
    @strategy = strategy
  end

  def call
    validate_inputs!
    clear_existing_forecasts
    generate_all_position_forecasts
  end

  private

  def validate_inputs!
    raise ArgumentError, "User must be a bot" unless user.bot?
    raise ArgumentError, "No gameweek available" unless gameweek
  end

  def generate_all_position_forecasts
    FantasyForecast::POSITION_CONFIG.keys.flat_map { |position| generate_position_forecasts(position) }
  end

  def generate_position_forecasts(position)
    config = config_for_position(position)
    rank_all_players(position, config).map { |data| create_forecast(data[:player], data[:rank]) }
  end

  def config_for_position(position)
    strategy_config.dig(:positions, position.to_sym) || strategy_config
  end

  def rank_all_players(position, config)
    players = Player.where(position: position).includes(:statistics, :team)
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
    players.sort_by { |p| -p[:score] }.each_with_index.map { |item, i| { player: item[:player], rank: i + 1 } }
  end

  def sort_alphabetically(players)
    players.sort_by { |p| p[:player].short_name.downcase }.map { |item| { player: item[:player], rank: nil } }
  end

  def clear_existing_forecasts
    Forecast.where(user: user, gameweek: gameweek).destroy_all
  end

  def create_forecast(player, rank)
    Forecast.create!(user: user, player: player, gameweek: gameweek, strategy: strategy, rank: rank)
  end
end
