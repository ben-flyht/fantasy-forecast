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
    raise ArgumentError, "User must be a bot" unless user.bot?
    raise ArgumentError, "No gameweek available" unless gameweek

    clear_existing_forecasts

    forecasts = []

    FantasyForecast::POSITION_CONFIG.each_key do |position|
      position_config = config_for_position(position)
      ranked_players = rank_all_players(position, position_config)

      ranked_players.each do |player_data|
        forecasts << create_forecast(player_data[:player], player_data[:rank])
      end
    end

    forecasts
  end

  private

  def config_for_position(position)
    if strategy_config[:positions]&.key?(position.to_sym)
      strategy_config[:positions][position.to_sym]
    else
      strategy_config
    end
  end

  def rank_all_players(position, config)
    players = Player.where(position: position).includes(:statistics, :team)

    # Score each player
    current_fpl_id = gameweek.fpl_id
    players_with_scores = players.map do |player|
      score = calculate_player_score(player, config, current_fpl_id)
      { player: player, score: score }
    end

    # Sort by score descending and assign ranks
    sorted = players_with_scores.sort_by { |p| -p[:score] }
    sorted.each_with_index.map do |item, index|
      { player: item[:player], rank: index + 1 }
    end
  end

  def clear_existing_forecasts
    Forecast.where(user: user, gameweek: gameweek).destroy_all
  end

  def create_forecast(player, rank)
    Forecast.create!(user: user, player: player, gameweek: gameweek, strategy: strategy, rank: rank)
  end
end
