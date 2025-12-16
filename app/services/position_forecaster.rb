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
    raise ArgumentError, "User must be a bot" unless user.bot?
    raise ArgumentError, "No gameweek available" unless gameweek
    raise ArgumentError, "Invalid position" unless valid_position?

    rank_all_players.map do |player_data|
      create_or_update_forecast(player_data[:player], player_data[:rank])
    end
  end

  private

  def valid_position?
    FantasyForecast::POSITION_CONFIG.key?(position)
  end

  def rank_all_players
    players = Player.where(position: position).includes(:statistics, :team)

    # Apply availability filter if configured
    if strategy_config[:filters]&.dig(:availability)
      min_chance = strategy_config[:filters][:availability][:min_chance_of_playing]
      if min_chance
        players = players.where("chance_of_playing >= ? OR chance_of_playing IS NULL", min_chance)
      end
    end

    # Score each player
    current_fpl_id = gameweek.fpl_id
    players_with_scores = players.map do |player|
      score = calculate_player_score(player, strategy_config, current_fpl_id)
      { player: player, score: score }
    end

    # Sort by score descending and assign ranks
    sorted = players_with_scores.sort_by { |p| -p[:score] }
    sorted.each_with_index.map do |item, index|
      { player: item[:player], rank: index + 1 }
    end
  end

  def create_or_update_forecast(player, rank)
    forecast = Forecast.find_or_initialize_by(user: user, player: player, gameweek: gameweek)
    forecast.strategy = strategy if strategy
    forecast.rank = rank
    forecast.save!
    forecast
  end
end
