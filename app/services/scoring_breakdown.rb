# Extracts scoring breakdown data for AI explanation generation
# Provides the same metrics used in strategy scoring, plus context about opponents
class ScoringBreakdown
  METRICS_WITH_CONTEXT = %w[goals_scored clean_sheets assists bonus].freeze
  POSITION_STATS = {
    "goalkeeper" => %w[clean_sheets saves bonus goals_conceded],
    "defender" => %w[clean_sheets goals_scored assists bonus],
    "midfielder" => %w[goals_scored assists bonus expected_goal_involvements],
    "forward" => %w[goals_scored assists bonus expected_goals]
  }.freeze
  METRIC_NAMES = {
    "total_points" => "FPL points", "goals_scored" => "goals", "expected_goals" => "xG",
    "expected_assists" => "xA", "expected_goal_involvements" => "xGI", "clean_sheets" => "clean sheets",
    "saves" => "saves", "bonus" => "bonus points", "ict_index" => "ICT index",
    "expected_goals_for" => "team xG", "expected_goals_against" => "opponent xG"
  }.freeze

  def initialize(player:, strategy_config:, gameweek:)
    @player = player
    @strategy_config = strategy_config
    @gameweek = gameweek
  end

  def call
    {
      player: player_info,
      upcoming_fixture: upcoming_fixture_info,
      recent_matches: recent_match_history,
      performance: performance_breakdown,
      fixture_difficulty: fixture_difficulty_info,
      availability: availability_info
    }
  end

  private

  def player_info
    { name: @player.short_name, position: @player.position, team: @player.team&.short_name || "Unknown" }
  end

  def upcoming_fixture_info
    match = find_upcoming_match
    return nil unless match

    build_fixture_info(match)
  end

  def build_fixture_info(match)
    is_home = match.home_team_id == @player.team_id
    {
      opponent: (is_home ? match.away_team : match.home_team).short_name,
      home_away: is_home ? "home" : "away",
      expected_goals_for: is_home ? match.home_team_expected_goals : match.away_team_expected_goals,
      expected_goals_against: is_home ? match.away_team_expected_goals : match.home_team_expected_goals
    }
  end

  def recent_match_history
    available_gameweeks(5).filter_map do |gw|
      match = find_match_for_gameweek(gw)
      performance = @player.performances.find { |p| p.gameweek_id == gw.id }
      build_match_summary(gw, match, performance) if match && performance
    end
  end

  def build_match_summary(gw, match, performance)
    is_home = match.home_team_id == @player.team_id
    {
      gameweek: gw.fpl_id,
      opponent: (is_home ? match.away_team : match.home_team).short_name,
      home_away: is_home ? "H" : "A",
      points: performance.gameweek_score,
      stats: extract_match_stats(gw)
    }
  end

  def extract_match_stats(gw)
    position_relevant_stats.each_with_object({}) do |stat_type, stats|
      stat = @player.statistics.find { |s| s.gameweek_id == gw.id && s.type == stat_type }
      value = stat&.value.to_f || 0
      stats[stat_type] = value if value > 0 || stat_type == "saves"
    end
  end

  def position_relevant_stats
    POSITION_STATS[@player.position] || %w[goals_scored assists bonus]
  end

  def performance_breakdown
    return [] unless @strategy_config[:performance]

    @strategy_config[:performance].map { |config| build_metric_breakdown(config) }
  end

  def build_metric_breakdown(config)
    recent_values = get_recent_values(config[:metric], config[:lookback])
    breakdown = base_breakdown(config, recent_values)
    breakdown[:context] = build_metric_context(config[:metric], config[:lookback]) if METRICS_WITH_CONTEXT.include?(config[:metric])
    breakdown
  end

  def base_breakdown(config, recent_values)
    {
      metric: human_metric_name(config[:metric]),
      weight: config[:weight],
      lookback: config[:lookback],
      recency: config[:recency],
      weighted_average: calculate_weighted_average(recent_values, config[:recency]).round(3),
      recent_gameweeks: recent_values
    }
  end

  def get_recent_values(metric, lookback)
    available_gameweeks(lookback).map do |gw|
      stat = @player.statistics.find { |s| s.gameweek_id == gw.id && s.type == metric }
      { gameweek: gw.fpl_id, value: stat&.value.to_f || 0.0 }
    end
  end

  def build_metric_context(metric, lookback)
    available_gameweeks(lookback).filter_map do |gw|
      stat = @player.statistics.find { |s| s.gameweek_id == gw.id && s.type == metric }
      next unless stat&.value.to_f&.positive?

      match = find_match_for_gameweek(gw)
      build_context_entry(gw, stat, match) if match
    end
  end

  def build_context_entry(gw, stat, match)
    is_home = match.home_team_id == @player.team_id
    {
      gameweek: gw.fpl_id,
      value: stat.value.to_f,
      opponent: (is_home ? match.away_team : match.home_team).short_name,
      home_away: is_home ? "H" : "A"
    }
  end

  def available_gameweeks(lookback)
    Gameweek.where("fpl_id < ?", @gameweek.fpl_id)
            .where("is_finished = ? OR start_time < ?", true, Time.current)
            .order(fpl_id: :desc)
            .limit(lookback)
            .reverse
  end

  def calculate_weighted_average(values, recency)
    return 0.0 if values.empty?

    weighted_total, weight_sum = values.each_with_index.reduce([ 0.0, 0.0 ]) do |(total, sum), (item, idx)|
      weight = recency_weight(idx, recency)
      [ total + (item[:value] * weight), sum + weight ]
    end

    weight_sum.positive? ? weighted_total / weight_sum : 0.0
  end

  def recency_weight(index, recency_type)
    case recency_type
    when "linear" then index + 1.0
    when "exponential" then 2.0**index
    else 1.0
    end
  end

  def fixture_difficulty_info
    return nil unless @strategy_config[:fixture]

    @strategy_config[:fixture].map { |config| build_fixture_difficulty(config) }
  end

  def build_fixture_difficulty(config)
    { metric: human_metric_name(config[:metric]), weight: config[:weight], value: get_fixture_value(config[:metric])&.round(2) }
  end

  def get_fixture_value(metric)
    match = find_upcoming_match
    return nil unless match

    is_home = match.home_team_id == @player.team_id
    case metric
    when "expected_goals_for" then is_home ? match.home_team_expected_goals : match.away_team_expected_goals
    when "expected_goals_against" then is_home ? match.away_team_expected_goals : match.home_team_expected_goals
    end
  end

  def availability_info
    chance = @player.chance_of_playing(@gameweek)
    { chance_of_playing: chance, status: availability_status(chance) }
  end

  def availability_status(chance)
    case chance
    when 100 then "fully fit"
    when 75..99 then "minor doubt"
    when 50..74 then "doubtful"
    when 25..49 then "major doubt"
    when 1..24 then "unlikely to play"
    else "ruled out"
    end
  end

  def find_upcoming_match
    find_match_for_gameweek(@gameweek)
  end

  def find_match_for_gameweek(gw)
    return nil unless @player.team_id

    Match.includes(:home_team, :away_team)
         .where(gameweek: gw)
         .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)
         .first
  end

  def human_metric_name(metric)
    METRIC_NAMES[metric] || metric.humanize.downcase
  end
end
