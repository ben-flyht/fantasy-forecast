# Extracts scoring breakdown data for AI explanation generation
# Provides the same metrics used in strategy scoring, plus context about opponents
class ScoringBreakdown
  METRICS_WITH_CONTEXT = %w[goals_scored clean_sheets assists bonus].freeze

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
    {
      name: @player.short_name,
      position: @player.position,
      team: @player.team&.short_name || "Unknown"
    }
  end

  def upcoming_fixture_info
    match = find_upcoming_match
    return nil unless match

    opponent = match.home_team_id == @player.team_id ? match.away_team : match.home_team
    home_away = match.home_team_id == @player.team_id ? "home" : "away"

    {
      opponent: opponent.short_name,
      home_away: home_away,
      expected_goals_for: match.home_team_id == @player.team_id ? match.home_team_expected_goals : match.away_team_expected_goals,
      expected_goals_against: match.home_team_id == @player.team_id ? match.away_team_expected_goals : match.home_team_expected_goals
    }
  end

  def recent_match_history
    gameweeks = available_gameweeks(5)
    return [] if gameweeks.empty?

    gameweeks.map do |gw|
      match = find_match_for_gameweek(gw)
      next unless match

      # Only include if player has performance data (game has been played)
      performance = @player.performances.find { |p| p.gameweek_id == gw.id }
      next unless performance

      build_match_summary(gw, match, performance)
    end.compact
  end

  def build_match_summary(gw, match, performance)
    opponent = match.home_team_id == @player.team_id ? match.away_team : match.home_team
    home_away = match.home_team_id == @player.team_id ? "H" : "A"
    points = performance&.gameweek_score || 0

    stats = extract_match_stats(gw)

    {
      gameweek: gw.fpl_id,
      opponent: opponent.short_name,
      home_away: home_away,
      points: points,
      stats: stats
    }
  end

  def extract_match_stats(gw)
    relevant_types = position_relevant_stats
    stats = {}

    relevant_types.each do |stat_type|
      stat = @player.statistics.find { |s| s.gameweek_id == gw.id && s.type == stat_type }
      value = stat&.value.to_f || 0
      stats[stat_type] = value if value > 0 || always_show_stat?(stat_type)
    end

    stats
  end

  def position_relevant_stats
    case @player.position
    when "goalkeeper"
      %w[clean_sheets saves bonus goals_conceded]
    when "defender"
      %w[clean_sheets goals_scored assists bonus]
    when "midfielder"
      %w[goals_scored assists bonus expected_goal_involvements]
    when "forward"
      %w[goals_scored assists bonus expected_goals]
    else
      %w[goals_scored assists bonus]
    end
  end

  def always_show_stat?(stat_type)
    %w[saves].include?(stat_type)
  end

  def performance_breakdown
    return [] unless @strategy_config[:performance]

    @strategy_config[:performance].map do |perf_config|
      build_metric_breakdown(perf_config)
    end
  end

  def build_metric_breakdown(perf_config)
    metric = perf_config[:metric]
    lookback = perf_config[:lookback]
    recency = perf_config[:recency]
    weight = perf_config[:weight]

    recent_values = get_recent_values(metric, lookback)
    weighted_avg = calculate_weighted_average(recent_values, recency)

    breakdown = {
      metric: human_metric_name(metric),
      weight: weight,
      lookback: lookback,
      recency: recency,
      weighted_average: weighted_avg.round(3),
      recent_gameweeks: recent_values
    }

    if METRICS_WITH_CONTEXT.include?(metric)
      breakdown[:context] = build_metric_context(metric, lookback)
    end

    breakdown
  end

  def get_recent_values(metric, lookback)
    gameweeks = available_gameweeks(lookback)

    gameweeks.map do |gw|
      stat = @player.statistics.find { |s| s.gameweek_id == gw.id && s.type == metric }
      {
        gameweek: gw.fpl_id,
        value: stat&.value.to_f || 0.0
      }
    end
  end

  def build_metric_context(metric, lookback)
    gameweeks = available_gameweeks(lookback)
    contexts = []

    gameweeks.each do |gw|
      stat = @player.statistics.find { |s| s.gameweek_id == gw.id && s.type == metric }
      next unless stat && stat.value.to_f > 0

      match = find_match_for_gameweek(gw)
      next unless match

      opponent = match.home_team_id == @player.team_id ? match.away_team : match.home_team

      contexts << {
        gameweek: gw.fpl_id,
        value: stat.value.to_f,
        opponent: opponent.short_name,
        home_away: match.home_team_id == @player.team_id ? "H" : "A"
      }
    end

    contexts
  end

  def available_gameweeks(lookback)
    # Include gameweeks that have started (not just finished) so we get
    # data from in-progress gameweeks where most games have been played
    Gameweek.where("fpl_id < ?", @gameweek.fpl_id)
            .where("is_finished = ? OR start_time < ?", true, Time.current)
            .order(fpl_id: :desc)
            .limit(lookback)
            .reverse
  end

  def calculate_weighted_average(values, recency)
    return 0.0 if values.empty?

    weighted_total = 0.0
    weight_sum = 0.0

    values.each_with_index do |item, index|
      weight = recency_weight(index, recency)
      weighted_total += item[:value] * weight
      weight_sum += weight
    end

    weight_sum > 0 ? weighted_total / weight_sum : 0.0
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

    @strategy_config[:fixture].map do |fixture_config|
      metric = fixture_config[:metric]
      weight = fixture_config[:weight]
      value = get_fixture_value(metric)

      {
        metric: human_metric_name(metric),
        weight: weight,
        value: value&.round(2)
      }
    end
  end

  def get_fixture_value(metric)
    match = find_upcoming_match
    return nil unless match

    case metric
    when "expected_goals_for"
      match.home_team_id == @player.team_id ? match.home_team_expected_goals : match.away_team_expected_goals
    when "expected_goals_against"
      match.home_team_id == @player.team_id ? match.away_team_expected_goals : match.home_team_expected_goals
    end
  end

  def availability_info
    chance = @player.chance_of_playing(@gameweek)
    {
      chance_of_playing: chance,
      status: availability_status(chance)
    }
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
    return nil unless @player.team_id

    Match.includes(:home_team, :away_team)
         .where(gameweek: @gameweek)
         .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)
         .first
  end

  def find_match_for_gameweek(gw)
    Match.includes(:home_team, :away_team)
         .where(gameweek: gw)
         .where("home_team_id = ? OR away_team_id = ?", @player.team_id, @player.team_id)
         .first
  end

  def human_metric_name(metric)
    {
      "total_points" => "FPL points",
      "goals_scored" => "goals",
      "expected_goals" => "xG",
      "expected_assists" => "xA",
      "expected_goal_involvements" => "xGI",
      "clean_sheets" => "clean sheets",
      "saves" => "saves",
      "bonus" => "bonus points",
      "ict_index" => "ICT index",
      "expected_goals_for" => "team xG",
      "expected_goals_against" => "opponent xG"
    }[metric] || metric.humanize.downcase
  end
end
