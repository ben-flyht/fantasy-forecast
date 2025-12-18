class PositionForecaster < ApplicationService
  include StrategyScoring

  attr_reader :user, :gameweek, :strategy_config, :position, :strategy

  def initialize(user:, strategy_config:, position:, gameweek:, strategy: nil)
    @user = user
    @strategy_config = strategy_config
    @position = position
    @gameweek = gameweek
    @strategy = strategy
  end

  def call
    validate_inputs!
    rank_all_players.map { |data| create_or_update_forecast(data[:player], data[:rank]) }
  end

  private

  def validate_inputs!
    raise ArgumentError, "User must be a bot" unless user.bot?
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
    players.sort_by { |p| -p[:score] }.each_with_index.map { |item, i| { player: item[:player], rank: i + 1 } }
  end

  def sort_alphabetically(players)
    players.sort_by { |p| p[:player].short_name.downcase }.map { |item| { player: item[:player], rank: nil } }
  end

  def create_or_update_forecast(player, rank)
    forecast = Forecast.find_or_initialize_by(user: user, player: player, gameweek: gameweek)
    forecast.strategy = strategy if strategy
    forecast.rank = rank
    forecast.save!
    forecast
  end
end
