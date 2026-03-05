class ExplanationBuilder
  def initialize(forecasts:, gameweek:, strategy_config:)
    @forecasts = forecasts
    @gameweek = gameweek
    @strategy_config = strategy_config
  end

  def call
    return {} if @forecasts.empty?

    @top_score = @forecasts.map(&:score).compact.max || 0
    @forecasts.each_with_object({}) do |forecast, results|
      results[forecast.id] = build_explanation(forecast)
    end
  end

  private

  def build_explanation(forecast)
    return snow_explanation(forecast) if snow_tier?(forecast)

    breakdown = breakdown_for(forecast)
    sentences = [ performance_sentence(breakdown), last_gw_sentence(forecast, breakdown), fixture_sentence(forecast, breakdown),
                   availability_sentence(forecast, breakdown) ]
    sentences << tier_sentence(forecast)
    sentences.compact.join(" ")
  end

  def breakdown_for(forecast)
    ScoringBreakdown.new(
      player: forecast.player,
      strategy_config: position_config(forecast.player.position),
      gameweek: @gameweek
    ).call
  end

  def performance_sentence(breakdown)
    metrics = breakdown[:performance]
    return nil if metrics.blank?

    lookback = metrics.first[:lookback]
    summaries = metrics.map { |m| "#{m[:weighted_average].round(1)} #{m[:metric]}" }
    "Averaging #{join_with_and(summaries)} over the last #{pluralize_match(lookback)}."
  end

  def last_gw_sentence(forecast, breakdown)
    matches = breakdown[:recent_matches]
    return nil if matches.blank?

    last = matches.last
    player_name = forecast.player.first_name
    opponent_str = format_opponents(last)
    stats = format_last_gw_stats(last[:stats])
    stat_str = stats.any? ? " with #{join_with_and(stats)}" : ""

    "In GW#{last[:gameweek]}, #{player_name} scored #{last[:points]} points #{opponent_str}#{stat_str}."
  end

  def format_opponents(match_data)
    if match_data[:double_gameweek]
      opponents = match_data[:opponents].map { |o| "#{o[:name]} (#{o[:venue] == 'H' ? 'H' : 'A'})" }
      "across two matches against #{join_with_and(opponents)}"
    else
      venue = match_data[:home_away] == "H" ? "at home against" : "away to"
      "#{venue} #{match_data[:opponent]}"
    end
  end

  LAST_GW_STAT_FORMATS = [
    [ "goals_scored", ->(v) { "#{v.to_i} goal#{'s' if v.to_i != 1}" } ],
    [ "assists", ->(v) { "#{v.to_i} assist#{'s' if v.to_i != 1}" } ],
    [ "clean_sheets", ->(_v) { "a clean sheet" } ],
    [ "saves", ->(v) { "#{v.to_i} saves" } ],
    [ "bonus", ->(v) { "#{v.to_i} bonus points" } ]
  ].freeze

  def format_last_gw_stats(stats)
    return [] if stats.blank?

    parts = LAST_GW_STAT_FORMATS.filter_map do |key, formatter|
      formatter.call(stats[key]) if stats[key].to_f > 0
    end
    parts << "#{stats['goals_conceded'].to_i} goals conceded" if conceded_without_cs?(stats)
    parts
  end

  def conceded_without_cs?(stats)
    stats["goals_conceded"].to_f > 0 && stats["clean_sheets"].to_f == 0
  end

  def pluralize_stat(value, word)
    count = value.to_i
    "#{count} #{word}#{'s' if count != 1}"
  end

  def fixture_sentence(forecast, breakdown)
    fixture = breakdown[:upcoming_fixture]
    return nil unless fixture

    player_name = forecast.player.short_name
    venue = fixture[:home_away] == "home" ? "at home" : "away"
    xg_part = fixture_xg_clause(breakdown[:fixture_difficulty])

    "#{player_name} faces #{fixture[:opponent_name]} #{venue} this week#{xg_part}."
  end

  def fixture_xg_clause(difficulties)
    return "" if difficulties.blank?

    fd = difficulties.first
    return "" unless fd[:value]

    lookback = fd[:lookback] || 6
    ", who have allowed #{fd[:value]} #{fd[:metric]} over the last #{pluralize_match(lookback)}"
  end

  def availability_sentence(forecast, breakdown)
    avail = breakdown[:availability]
    player = forecast.player
    news = player.news

    if avail && avail[:chance_of_playing] < 100
      base = "#{avail[:chance_of_playing]}% chance of playing (#{avail[:status]})"
      news.present? ? "#{base} — #{news}." : "#{base}."
    elsif news.present?
      "Note: #{news}."
    end
  end

  def snow_explanation(forecast)
    news = forecast.player.news
    return truncate(news) if news.present?

    chance = forecast.player.chance_of_playing(@gameweek)
    case chance
    when 0 then "Ruled out."
    when 1..49 then "Unlikely to play."
    when 50..74 then "Fitness doubt."
    end
  end

  TIER_DESCRIPTIONS = {
    1 => "a top tier pick",
    2 => "a strong option",
    3 => "a solid but unpredictable option",
    4 => "a risky pick"
  }.freeze

  def tier_sentence(forecast)
    tier = calculate_tier(forecast)
    desc = TIER_DESCRIPTIONS[tier]
    return nil unless desc

    player = forecast.player
    team_name = player.team&.name
    team_clause = team_name ? "#{team_name} #{player.position}" : player.position
    "We consider #{player.first_name} #{desc} for FPL in Gameweek #{@gameweek.fpl_id} as a #{team_clause}."
  end

  def calculate_tier(forecast)
    return 5 if forecast.score.nil? || @top_score.zero?

    percentage = ((@top_score - forecast.score) / @top_score.to_f) * 100
    case percentage
    when -Float::INFINITY..20 then 1
    when 20..40 then 2
    when 40..60 then 3
    when 60..80 then 4
    else 5
    end
  end

  def snow_tier?(forecast)
    return true if forecast.score.nil?
    return true if @top_score.zero?

    percentage = ((@top_score - forecast.score) / @top_score.to_f) * 100
    percentage > 80
  end

  def position_config(position)
    @strategy_config.dig(:positions, position.to_sym) || @strategy_config
  end

  def join_with_and(items)
    case items.length
    when 1 then items.first
    when 2 then items.join(" and ")
    else "#{items[0..-2].join(', ')} and #{items.last}"
    end
  end

  def pluralize_match(count)
    count == 1 ? "1 match" : "#{count} matches"
  end

  def truncate(text)
    text.length > 60 ? "#{text[0, 57]}..." : text
  end
end
