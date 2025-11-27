class StrategyRunner < ApplicationService
  attr_reader :config, :position, :count, :gameweek

  RECENCY_TYPES = %w[none linear exponential].freeze

  def initialize(config, position:, count:, gameweek:)
    @config = config || {}
    @position = position
    @count = count
    @gameweek = gameweek
    validate_config!
  end

  def call
    if config.empty? || config[:strategies].nil?
      select_random
    else
      select_by_weighted_strategies
    end
  end

  private

  def validate_config!
    return if config.empty?
    return unless config[:strategies]

    config[:strategies].each do |strategy|
      unless RECENCY_TYPES.include?(strategy[:recency])
        raise ArgumentError, "Invalid recency type: #{strategy[:recency]}. Must be one of: #{RECENCY_TYPES.join(', ')}"
      end

      unless valid_metric_types.include?(strategy[:metric])
        raise ArgumentError, "Invalid metric: #{strategy[:metric]}. Must be one of: #{valid_metric_types.join(', ')}"
      end
    end
  end

  def valid_metric_types
    @valid_metric_types ||= Statistic.distinct.pluck(:type)
  end

  def select_random
    Player.where(position: position).to_a.sample(count)
  end

  def select_by_weighted_strategies
    current_fpl_id = gameweek.fpl_id
    players = Player.where(position: position).includes(:statistics)

    # Apply availability filter if configured
    # Only filters out players with explicitly low availability (< min_chance)
    # NULL values are acceptable (unknown availability)
    if config[:filters]&.dig(:availability)
      min_chance = config[:filters][:availability][:min_chance_of_playing]
      if min_chance
        players = players.where("chance_of_playing >= ? OR chance_of_playing IS NULL", min_chance)
      end
    end

    # Calculate composite score for each player
    players_with_scores = players.map do |player|
      composite_score = calculate_composite_score(player, current_fpl_id)
      { player: player, score: composite_score }
    end

    # Sort by composite score (descending) and take top N
    players_with_scores
      .sort_by { |p| -p[:score] }
      .first(count)
      .map { |p| p[:player] }
  end

  def calculate_composite_score(player, current_fpl_id)
    total_score = 0.0

    config[:strategies].each do |strategy|
      metric = strategy[:metric]
      weight = strategy[:weight]
      lookback = strategy[:lookback]
      recency = strategy[:recency]

      # Calculate the weighted metric score
      metric_score = calculate_metric_score(player, metric, current_fpl_id, lookback, recency)
      total_score += metric_score * weight
    end

    total_score
  end

  def calculate_metric_score(player, metric, current_fpl_id, lookback, recency)
    start_fpl_id = [ current_fpl_id - lookback, 1 ].max

    # Get performances/statistics for the lookback window
    gameweeks_in_range = (start_fpl_id...current_fpl_id).to_a

    # Calculate weighted score based on recency
    weighted_total = 0.0
    weight_sum = 0.0

    gameweeks_in_range.each_with_index do |fpl_id, index|
      value = get_metric_value(player, metric, fpl_id)
      recency_weight = calculate_recency_weight(index, gameweeks_in_range.size, recency)

      weighted_total += value * recency_weight
      weight_sum += recency_weight
    end

    # Return normalized score (avoid division by zero)
    weight_sum > 0 ? weighted_total / weight_sum : 0.0
  end

  def get_metric_value(player, metric, fpl_id)
    gameweek = gameweeks_by_fpl_id[fpl_id]
    return 0.0 unless gameweek

    # Get from statistics (uses preloaded association)
    statistic = player.statistics.find { |s| s.gameweek_id == gameweek.id && s.type == metric }
    return 0.0 unless statistic
    statistic.value.to_f
  end

  def gameweeks_by_fpl_id
    @gameweeks_by_fpl_id ||= Gameweek.all.index_by(&:fpl_id)
  end

  def calculate_recency_weight(index, total_weeks, recency_type)
    case recency_type
    when "none"
      1.0
    when "linear"
      # Weight increases linearly: 1, 2, 3, 4, 5
      index + 1.0
    when "exponential"
      # Weight increases exponentially: 2^0, 2^1, 2^2, 2^3, 2^4
      2.0 ** index
    else
      1.0
    end
  end
end
