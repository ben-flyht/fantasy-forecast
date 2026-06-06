class BotForecaster < ApplicationService
  include StrategyScoring

  attr_reader :gameweek, :strategy_config, :strategy

  def initialize(strategy_config:, gameweek:, strategy: nil, **)
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
    raise ArgumentError, "No gameweek available" unless gameweek
  end

  def generate_all_position_forecasts
    FantasyForecast::POSITION_CONFIG.keys.flat_map { |position| generate_position_forecasts(position) }
  end

  def generate_position_forecasts(position)
    config = config_for_position(position)
    ranked_players = rank_all_players(position, config)
    @current_top_score = ranked_players.first&.dig(:score) || 0
    ranked_players.map { |data| create_forecast(data[:player_id], data[:rank], data[:score]) }
  end

  def config_for_position(position)
    strategy_config.dig(:positions, position.to_sym) || strategy_config
  end

  def rank_all_players(position, config)
    current_fpl_id = gameweek.fpl_id
    scored = []
    Player.where(position: position).find_each do |player|
      scored << build_scored_player(player, config, current_fpl_id)
    end
    assign_ranks(scored)
  end

  def build_scored_player(player, config, current_fpl_id)
    {
      player_id: player.id,
      short_name: player.short_name,
      score: calculate_player_score(player, config, current_fpl_id),
      available: player_available?(player)
    }
  end

  def player_available?(player)
    return false unless team_has_fixture?(player.team_id)

    chance_of_playing_for(player).positive?
  end

  def team_has_fixture?(team_id)
    teams_with_fixtures.include?(team_id)
  end

  def teams_with_fixtures
    @teams_with_fixtures ||= Match.where(gameweek: gameweek)
      .pluck(:home_team_id, :away_team_id)
      .flatten
      .to_set
  end

  def assign_ranks(scored_players)
    available, unavailable = scored_players.partition { |p| p[:available] }
    rank_by_score(available) + sort_alphabetically(unavailable)
  end

  def rank_by_score(players)
    players.sort_by { |p| [ -p[:score], p[:player_id] ] }.each_with_index.map do |item, i|
      { player_id: item[:player_id], rank: i + 1, score: item[:score] }
    end
  end

  def sort_alphabetically(players)
    players.sort_by { |p| [ p[:short_name].to_s.downcase, p[:player_id] ] }.map do |item|
      { player_id: item[:player_id], rank: nil, score: item[:score] }
    end
  end

  def clear_existing_forecasts
    Forecast.where(gameweek: gameweek).destroy_all
  end

  def create_forecast(player_id, rank, score)
    Forecast.create!(player_id: player_id, gameweek: gameweek, strategy: strategy, rank: rank, score: score)
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
