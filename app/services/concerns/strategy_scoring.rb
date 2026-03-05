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
      get_fixture_metric_value(player, fixture_config[:metric], fixture_config[:lookback] || 6) * fixture_config[:weight]
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
    avg = compute_weighted_average(player, metric, gameweeks_to_score, recency)
    avg * sample_confidence(gameweeks_to_score, player.team_id, lookback)
  end

  def sample_confidence(gameweeks, team_id, target_matches)
    match_counts = matches_per_gameweek(team_id)
    actual = gameweeks.sum { |fpl_id| match_counts[fpl_id] || 1 }
    [ actual.to_f / target_matches, 1.0 ].min
  end

  def available_gameweeks_for_lookback(player, current_fpl_id, lookback, min_availability)
    available_fpl_ids = get_available_gameweeks(player, current_fpl_id, min_availability)
    select_gameweeks_by_match_count(available_fpl_ids, player.team_id, lookback)
  end

  def select_gameweeks_by_match_count(fpl_ids, team_id, target_matches)
    match_counts = matches_per_gameweek(team_id)
    selected = []
    total = 0

    fpl_ids.reverse_each do |fpl_id|
      break if total >= target_matches

      selected.unshift(fpl_id)
      total += match_counts[fpl_id] || 1
    end

    selected
  end

  def compute_weighted_average(player, metric, gameweeks_to_score, recency)
    match_counts = matches_per_gameweek(player.team_id)
    weighted_total = 0.0
    weight_sum = 0.0

    gameweeks_to_score.each_with_index do |fpl_id, index|
      per_match_value = per_match_metric(player, metric, fpl_id, match_counts)
      recency_weight = calculate_recency_weight(index, recency)
      weighted_total += per_match_value * recency_weight
      weight_sum += recency_weight
    end

    weight_sum > 0 ? weighted_total / weight_sum : 0.0
  end

  def per_match_metric(player, metric, fpl_id, match_counts)
    value = get_metric_value(player, metric, fpl_id)
    value / (match_counts[fpl_id] || 1)
  end

  def matches_per_gameweek(team_id)
    @matches_per_gameweek ||= {}
    @matches_per_gameweek[team_id] ||= build_matches_per_gameweek(team_id)
  end

  def build_matches_per_gameweek(team_id)
    Match.joins(:gameweek)
         .where("home_team_id = ? OR away_team_id = ?", team_id, team_id)
         .group("gameweeks.fpl_id")
         .count
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

  # Check if the player actually played in this gameweek.
  # Excludes gameweeks where the player had 0 minutes (rested, injured, suspended).
  def team_has_played?(fpl_id, minutes_by_gw_id)
    gw = gameweeks_by_fpl_id[fpl_id]
    return false unless gw

    minutes_stat = minutes_by_gw_id[gw.id]
    minutes_stat.present? && minutes_stat.value > 0
  end

  def get_metric_value(player, metric, fpl_id)
    gw = gameweeks_by_fpl_id[fpl_id]
    return 0.0 unless gw

    statistic = player.statistics.find { |s| s.gameweek_id == gw.id && s.type == metric }
    statistic&.value.to_f || 0.0
  end

  def get_fixture_metric_value(player, metric, lookback = 6)
    xg = team_expected_goals(lookback)[player.team_id]
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

  def team_expected_goals(lookback)
    @team_expected_goals ||= {}
    @team_expected_goals[lookback] ||= build_team_expected_goals(lookback)
  end

  def build_team_expected_goals(lookback)
    matches = Match.where(gameweek: gameweek)
    finished_gw_ids = finished_gameweek_ids_for_lookback(lookback)
    return {} if finished_gw_ids.empty?

    team_stats = load_team_xg_stats(matches, finished_gw_ids)
    map_match_xg(matches, team_stats, finished_gw_ids)
  end

  def finished_gameweek_ids_for_lookback(lookback)
    Gameweek.where(is_finished: true).order(fpl_id: :desc).limit(lookback).pluck(:id)
  end

  def load_team_xg_stats(matches, finished_gw_ids)
    team_ids = matches.flat_map { |m| [ m.home_team_id, m.away_team_id ] }.uniq

    Statistic.joins(:player)
             .where(players: { team_id: team_ids })
             .where(gameweek_id: finished_gw_ids)
             .where(type: %w[expected_goals expected_goals_conceded])
             .select(:type, :value, :gameweek_id, "players.team_id AS team_id")
             .group_by(&:team_id)
  end

  def map_match_xg(matches, team_stats, finished_gw_ids)
    matches.each_with_object({}) do |match, hash|
      hash[match.home_team_id] = xg_pair(team_stats[match.away_team_id], finished_gw_ids)
      hash[match.away_team_id] = xg_pair(team_stats[match.home_team_id], finished_gw_ids)
    end
  end

  def xg_pair(opponent_stats, finished_gw_ids)
    { for: avg_xg_conceded(opponent_stats, finished_gw_ids), against: avg_xg_scored(opponent_stats, finished_gw_ids) }
  end

  # Average of opponent's expected_goals_conceded per GW (max per team per GW for full-match value)
  def avg_xg_conceded(stats, gw_ids)
    return 0.0 unless stats

    by_gw = stats.select { |s| s.type == "expected_goals_conceded" }.group_by(&:gameweek_id)
    return 0.0 if by_gw.empty?

    gw_values = gw_ids.filter_map { |gw_id| by_gw[gw_id]&.map(&:value)&.max }
    gw_values.empty? ? 0.0 : gw_values.sum / gw_values.size
  end

  # Average of opponent's total expected_goals per GW (sum of all players per GW)
  def avg_xg_scored(stats, gw_ids)
    return 0.0 unless stats

    by_gw = stats.select { |s| s.type == "expected_goals" }.group_by(&:gameweek_id)
    return 0.0 if by_gw.empty?

    gw_values = gw_ids.filter_map { |gw_id| by_gw[gw_id]&.sum(&:value) }
    gw_values.empty? ? 0.0 : gw_values.sum / gw_values.size
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
