class StrategyEvaluator < ApplicationService
  include StrategyScoring

  MIN_GAMEWEEKS = 10

  attr_reader :gameweek, :strategy_config

  def initialize(strategy_config:, position:, gameweek_range: nil)
    @strategy_config = strategy_config.deep_symbolize_keys
    @position = position
    @gameweek_range = gameweek_range || default_gameweek_range
  end

  def call
    return empty_result if @gameweek_range.size < MIN_GAMEWEEKS

    preload_players!
    scores = evaluate_gameweeks
    aggregate_scores(scores)
  end

  private

  def preload_players!
    @players = Player.where(position: @position).includes(:statistics, :team, :performances).to_a
  end

  def evaluate_gameweeks
    @gameweek_range.filter_map do |gw|
      @gameweek = gw
      reset_caches!
      evaluate_single_gameweek(gw)
    end
  end

  def evaluate_single_gameweek(gw)
    actuals = Performance.where(gameweek: gw, player_id: @players.map(&:id)).index_by(&:player_id)
    return nil if actuals.empty?

    rankings = rank_players(gw)
    score_rankings(rankings, actuals)
  end

  def rank_players(gw)
    config = @strategy_config.dig(:positions, @position.to_sym) || @strategy_config
    scored = @players.map do |p|
      { player_id: p.id, score: calculate_player_score(p, config, gw.fpl_id) }
    end
    scored.sort_by { |s| -s[:score] }
  end

  def score_rankings(rankings, actuals)
    ranked_with_actuals = rankings.filter_map.with_index do |entry, idx|
      actual = actuals[entry[:player_id]]
      next unless actual

      { rank: idx + 1, actual_points: actual.gameweek_score }
    end

    compute_capture(ranked_with_actuals)
  end

  def compute_capture(ranked_with_actuals)
    slots = position_slots
    predicted_points = ranked_with_actuals.first(slots).sum { |r| r[:actual_points] }
    optimal_points = ranked_with_actuals.sort_by { |r| -r[:actual_points] }.first(slots).sum { |r| r[:actual_points] }

    {
      capture: optimal_points.zero? ? 0.0 : predicted_points.to_f / optimal_points,
      predicted_points: predicted_points,
      optimal_points: optimal_points
    }
  end

  def position_slots
    config = FantasyForecast::POSITION_CONFIG[@position]
    config["slots"] || config[:slots] || 3
  end

  def aggregate_scores(scores)
    return empty_result if scores.empty?

    {
      capture_rate: (scores.sum { |s| s[:capture] } / scores.size * 100).round(1),
      total_predicted: scores.sum { |s| s[:predicted_points] },
      total_optimal: scores.sum { |s| s[:optimal_points] },
      gameweeks_evaluated: scores.size,
      per_gameweek: scores
    }
  end

  def empty_result
    { capture_rate: 0.0, total_predicted: 0, total_optimal: 0, gameweeks_evaluated: 0, per_gameweek: [] }
  end

  def default_gameweek_range
    Gameweek.finished
            .where(fpl_id: MIN_GAMEWEEKS..Float::INFINITY)
            .joins("INNER JOIN performances ON performances.gameweek_id = gameweeks.id")
            .distinct
            .order(:fpl_id)
            .to_a
  end

  def reset_caches!
    @matches_per_gameweek = nil
    @team_expected_goals = nil
    @current_gameweek_matches = nil
  end
end
