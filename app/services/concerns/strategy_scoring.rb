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

    score = calculate_performance_score(player, config, current_fpl_id)
    score += calculate_fixture_score(player, config)
    apply_availability_to_score(score, player, config)
  end

  def calculate_performance_score(player, config, current_fpl_id)
    config[:performance].sum do |perf_config|
      metric_score = calculate_metric_score(player, perf_config, current_fpl_id)
      metric_score * perf_config[:weight]
    end
  end

  def calculate_fixture_score(player, config)
    return 0.0 unless config[:fixture]

    config[:fixture].sum do |fixture_config|
      get_fixture_metric_value(player, fixture_config[:metric]) * fixture_config[:weight]
    end
  end

  def apply_availability_to_score(score, player, config)
    return score unless config[:availability]

    weight = config[:availability][:weight] || 1.0
    apply_availability(score, player, weight)
  end

  def calculate_metric_score(player, perf_config, current_fpl_id)
    metric = perf_config[:metric]
    return get_fixture_metric_value(player, metric) if fixture_metric?(metric)

    lookback = perf_config[:lookback]
    recency = perf_config[:recency]
    min_availability = perf_config[:min_availability] || DEFAULT_MIN_AVAILABILITY

    calculate_weighted_metric(player, metric, current_fpl_id, lookback, recency, min_availability)
  end

  def calculate_weighted_metric(player, metric, current_fpl_id, lookback, recency, min_availability)
    gameweeks_to_score = available_gameweeks_for_lookback(player, current_fpl_id, lookback, min_availability)
    compute_weighted_average(player, metric, gameweeks_to_score, recency)
  end

  def available_gameweeks_for_lookback(player, current_fpl_id, lookback, min_availability)
    available_fpl_ids = get_available_gameweeks(player, current_fpl_id, min_availability)
    available_fpl_ids.last(lookback)
  end

  def compute_weighted_average(player, metric, gameweeks_to_score, recency)
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

  def get_available_gameweeks(player, current_fpl_id, min_availability)
    availability_by_gw_id = player_availability_map(player)
    minutes_by_gw_id = player_minutes_map(player)
    filter_available_gameweeks(current_fpl_id, availability_by_gw_id, minutes_by_gw_id, min_availability)
  end

  def player_availability_map(player)
    player.statistics.select { |s| s.type == "chance_of_playing" }.index_by(&:gameweek_id)
  end

  def player_minutes_map(player)
    player.statistics.select { |s| s.type == "minutes" }.index_by(&:gameweek_id)
  end

  def filter_available_gameweeks(current_fpl_id, availability_by_gw_id, minutes_by_gw_id, min_availability)
    (1...current_fpl_id).select do |fpl_id|
      team_has_played?(fpl_id, minutes_by_gw_id) &&
        gameweek_available?(fpl_id, availability_by_gw_id, min_availability)
    end
  end

  def gameweek_available?(fpl_id, availability_by_gw_id, min_availability)
    gw = gameweeks_by_fpl_id[fpl_id]
    return false unless gw

    availability_stat = availability_by_gw_id[gw.id]
    availability_stat.nil? || availability_stat.value >= min_availability
  end

  # Check if the team has played their match in this gameweek.
  # For finished gameweeks: always true (all matches complete).
  # For in-progress gameweeks: check if player has minutes > 0 (their specific match happened).
  def team_has_played?(fpl_id, minutes_by_gw_id)
    gw = gameweeks_by_fpl_id[fpl_id]
    return false unless gw
    return true if gw.is_finished

    # For current GW, only include if player's match has been played
    minutes_stat = minutes_by_gw_id[gw.id]
    minutes_stat.present? && minutes_stat.value > 0
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
    when "expected_goals_for" then xg[:for] || 0.0
    when "expected_goals_against" then xg[:against] || 0.0
    else 0.0
    end
  end

  def fixture_metric?(metric)
    FIXTURE_METRICS.include?(metric)
  end

  def team_expected_goals
    @team_expected_goals ||= build_team_expected_goals
  end

  def build_team_expected_goals
    Match.where(gameweek: gameweek).each_with_object({}) do |match, hash|
      hash[match.home_team_id] = { for: match.home_team_expected_goals, against: match.away_team_expected_goals }
      hash[match.away_team_id] = { for: match.away_team_expected_goals, against: match.home_team_expected_goals }
    end
  end

  def gameweeks_by_fpl_id
    @gameweeks_by_fpl_id ||= Gameweek.all.index_by(&:fpl_id)
  end

  def calculate_recency_weight(index, recency_type)
    case recency_type
    when "none" then 1.0
    when "linear" then index + 1.0
    when "exponential" then 2.0**index
    else 1.0
    end
  end

  def apply_availability(score, player, weight)
    chance = player.chance_of_playing(gameweek) || 100
    adjusted = score * availability_multiplier(chance, weight)
    chance == 0 ? adjusted - (1000.0 * weight) : adjusted
  end

  def availability_multiplier(chance, weight)
    availability_ratio = chance / 100.0
    1.0 - (weight * (1.0 - availability_ratio))
  end
end
