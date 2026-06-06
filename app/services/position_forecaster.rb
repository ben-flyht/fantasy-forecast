class PositionForecaster < ApplicationService
  include StrategyScoring

  attr_reader :gameweek, :strategy_config, :position, :strategy

  def initialize(strategy_config:, position:, gameweek:, strategy: nil, **)
    @strategy_config = strategy_config
    @position = position
    @gameweek = gameweek
    @strategy = strategy
  end

  def call
    validate_inputs!
    ranked_players = rank_all_players
    @top_score = ranked_players.first&.dig(:score) || 0
    ranked_players.map { |data| create_or_update_forecast(data[:player_id], data[:rank], data[:score]) }
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
    current_fpl_id = gameweek.fpl_id
    scored = []
    Player.where(position: position).find_each do |player|
      scored << build_scored_player(player, current_fpl_id)
    end
    assign_ranks(scored)
  end

  def build_scored_player(player, current_fpl_id)
    {
      player_id: player.id,
      short_name: player.short_name,
      score: calculate_player_score(player, strategy_config, current_fpl_id),
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

  def create_or_update_forecast(player_id, rank, score)
    forecast = Forecast.find_or_initialize_by(player_id: player_id, gameweek: gameweek)
    forecast.strategy = strategy if strategy
    forecast.rank = rank
    forecast.score = score
    forecast.save!
    forecast
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
