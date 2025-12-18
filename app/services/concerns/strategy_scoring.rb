# Shared scoring logic for strategy-based player evaluation
# Used by BotForecaster and PositionForecaster
module StrategyScoring
  extend ActiveSupport::Concern

  FIXTURE_METRICS = %w[expected_goals_for expected_goals_against].freeze
  RECENCY_TYPES = %w[none linear exponential].freeze
  DEFAULT_MIN_AVAILABILITY = 50 # Players with 50%+ chance of playing are considered "available"

  private

  def calculate_player_score(player, config, current_fpl_id)
    return 0.0 if config.empty? || config[:performance].nil?

    total_score = 0.0

    config[:performance].each do |perf_config|
      metric = perf_config[:metric]
      weight = perf_config[:weight]
      lookback = perf_config[:lookback]
      recency = perf_config[:recency]
      min_availability = perf_config[:min_availability] || DEFAULT_MIN_AVAILABILITY

      metric_score = calculate_metric_score(player, metric, current_fpl_id, lookback, recency, min_availability)
      total_score += metric_score * weight
    end

    if config[:fixture]
      config[:fixture].each do |fixture_config|
        metric = fixture_config[:metric]
        weight = fixture_config[:weight]

        metric_score = get_fixture_metric_value(player, metric)
        total_score += metric_score * weight
      end
    end

    # Apply availability if configured
    if config[:availability]
      weight = config[:availability][:weight] || 1.0
      total_score = apply_availability(total_score, player, weight)
    end

    total_score
  end

  def calculate_metric_score(player, metric, current_fpl_id, lookback, recency, min_availability = DEFAULT_MIN_AVAILABILITY)
    return get_fixture_metric_value(player, metric) if fixture_metric?(metric)

    # Get gameweeks where player was available (not injured)
    # This filters out injury periods from lookback
    available_fpl_ids = get_available_gameweeks(player, current_fpl_id, min_availability)

    # Take the most recent N available gameweeks (not calendar gameweeks)
    gameweeks_to_score = available_fpl_ids.last(lookback)

    weighted_total = 0.0
    weight_sum = 0.0

    gameweeks_to_score.each_with_index do |fpl_id, index|
      value = get_metric_value(player, metric, fpl_id)
      recency_weight = calculate_recency_weight(index, recency)

      weighted_total += value * recency_weight
      weight_sum += recency_weight
    end

    weight_sum > 0 ? weighted_total / weight_sum : 0.0
  end

  # Returns FPL IDs of gameweeks where the player was available (not injured)
  # If no availability data exists for a gameweek, assumes player was available (backward compatibility)
  def get_available_gameweeks(player, current_fpl_id, min_availability)
    # Get chance_of_playing stats for this player, indexed by gameweek id
    availability_by_gw_id = player.statistics
      .select { |s| s.type == "chance_of_playing" }
      .index_by(&:gameweek_id)

    # Filter gameweeks before current where player was available
    (1...current_fpl_id).select do |fpl_id|
      gw = gameweeks_by_fpl_id[fpl_id]
      next false unless gw

      availability_stat = availability_by_gw_id[gw.id]

      # If no availability data, assume player was available (backward compatibility)
      # Otherwise, check if availability meets threshold
      availability_stat.nil? || availability_stat.value >= min_availability
    end
  end

  def get_metric_value(player, metric, fpl_id)
    gw = gameweeks_by_fpl_id[fpl_id]
    return 0.0 unless gw

    statistic = player.statistics.find { |s| s.gameweek_id == gw.id && s.type == metric }
    statistic&.value.to_f || 0.0
  end

  def get_fixture_metric_value(player, metric)
    xg = team_expected_goals[player.team_id]
    return 0.0 unless xg

    case metric
    when "expected_goals_for"
      xg[:for] || 0.0
    when "expected_goals_against"
      xg[:against] || 0.0
    else
      0.0
    end
  end

  def fixture_metric?(metric)
    FIXTURE_METRICS.include?(metric)
  end

  def team_expected_goals
    @team_expected_goals ||= Match.where(gameweek: gameweek).each_with_object({}) do |match, hash|
      hash[match.home_team_id] = { for: match.home_team_expected_goals, against: match.away_team_expected_goals }
      hash[match.away_team_id] = { for: match.away_team_expected_goals, against: match.home_team_expected_goals }
    end
  end

  def gameweeks_by_fpl_id
    @gameweeks_by_fpl_id ||= Gameweek.all.index_by(&:fpl_id)
  end

  def calculate_recency_weight(index, recency_type)
    case recency_type
    when "none"
      1.0
    when "linear"
      index + 1.0
    when "exponential"
      2.0**index
    else
      1.0
    end
  end

  # Apply availability to score
  # - multiplier scales the performance score based on availability
  # - large penalty only for 0% availability (injured/suspended) to push to bottom
  def apply_availability(score, player, weight)
    # Use chance_of_playing for the target gameweek we're forecasting for
    chance = player.chance_of_playing(gameweek) || 100  # Default to fully available
    availability_ratio = chance / 100.0
    multiplier = 1.0 - (weight * (1.0 - availability_ratio))

    # Apply multiplier to scale score by availability
    adjusted_score = score * multiplier

    # Only apply large penalty for completely unavailable players (0%)
    # This ensures injured players rank below everyone else
    if chance == 0
      adjusted_score -= 1000.0 * weight
    end

    adjusted_score
  end
end
