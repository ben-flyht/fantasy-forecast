# Generates AI-powered explanations for multiple players in a single API call
class BatchExplanationGenerator
  class GenerationError < StandardError; end

  MODEL = "claude-3-5-haiku-latest".freeze
  SNOW_TIER = 5

  def initialize(forecasts:, gameweek:, strategy_config:)
    @forecasts = forecasts
    @gameweek = gameweek
    @strategy_config = strategy_config
  end

  def call
    return {} if @forecasts.empty?

    results = {}
    snow_forecasts, other_forecasts = partition_by_tier

    snow_forecasts.each { |f| results[f.id] = snow_tier_explanation(f) }
    results.merge!(generate_batch_explanations(other_forecasts)) if other_forecasts.any?

    results
  end

  private

  def partition_by_tier
    @forecasts.partition { |f| calculate_tier(f) == SNOW_TIER }
  end

  def calculate_tier(forecast)
    return SNOW_TIER if forecast.score.nil?

    top_score = @forecasts.map(&:score).compact.max || 0
    return SNOW_TIER if top_score.zero?

    tier_from_percentage(((top_score - forecast.score) / top_score.to_f) * 100)
  end

  def tier_from_percentage(percentage)
    case percentage
    when -Float::INFINITY..20 then 1
    when 20..40 then 2
    when 40..60 then 3
    when 60..80 then 4
    else SNOW_TIER
    end
  end

  def snow_tier_explanation(forecast)
    news = forecast.player.news
    return truncate_news(news) if news.present?

    availability_explanation(forecast.player.chance_of_playing(@gameweek))
  end

  def availability_explanation(chance)
    case chance
    when 0 then "Ruled out."
    when 1..49 then "Unlikely to play."
    when 50..74 then "Fitness doubt."
    end
  end

  def truncate_news(news)
    news.length > 60 ? "#{news[0, 57]}..." : news
  end

  def generate_batch_explanations(forecasts)
    breakdowns = build_breakdowns(forecasts)
    prompt = build_batch_prompt(forecasts, breakdowns)
    response = call_api(prompt)
    parse_response(response, forecasts)
  rescue Anthropic::APIError, StandardError => e
    Rails.logger.error("Batch explanation generation failed: #{e.message}")
    {}
  end

  def call_api(prompt)
    client.messages.create(
      model: MODEL,
      max_tokens: 8000,
      messages: [ { role: "user", content: prompt } ]
    )
  end

  def build_breakdowns(forecasts)
    forecasts.each_with_object({}) do |forecast, hash|
      hash[forecast.id] = ScoringBreakdown.new(
        player: forecast.player,
        strategy_config: position_config(forecast.player.position),
        gameweek: @gameweek
      ).call
    end
  end

  def position_config(position)
    @strategy_config.dig(:positions, position.to_sym) || @strategy_config
  end

  def build_batch_prompt(forecasts, breakdowns)
    player_lines = forecasts.each_with_index.map do |forecast, idx|
      build_player_line(idx + 1, forecast, breakdowns[forecast.id])
    end

    prompt_template(player_lines.join("\n\n"))
  end

  def prompt_template(player_lines)
    <<~PROMPT
      Generate 2-sentence explanations for each player's FPL ranking.

      Sentence 1: Recent form - reference SPECIFIC gameweeks and matches (e.g., "Scored twice vs Newcastle in GW21, just 1 goal in previous 3 games.")
      Sentence 2: Fixture outlook - mention the upcoming opponent specifically (e.g., "Faces leaky Wolves who conceded 8 in last 4.")

      IMPORTANT: Use the gameweek numbers provided (GW20, GW21, etc.) to give temporal context.
      Be specific with stats and opponent names. Avoid generic phrases like "good form" or "favourable fixture".

      #{player_lines}

      Return ONLY valid JSON with player numbers as keys:
      {"1": "Two sentence explanation here.", "2": "Two sentence explanation here.", ...}
    PROMPT
  end

  def build_player_line(number, forecast, breakdown)
    player = forecast.player
    matches = breakdown[:recent_matches] || []

    <<~LINE.strip
      #{number}. #{player_header(player, forecast, breakdown[:upcoming_fixture])}
         Last GW: #{format_last_gameweek(matches)}
         Form (last 5): #{format_recent_summary(matches)}
    LINE
  end

  def player_header(player, forecast, fixture)
    opponent = fixture ? "vs #{fixture[:opponent]}(#{fixture[:home_away][0].upcase})" : ""
    "#{player.short_name} ##{forecast.rank} (#{player.position.upcase[0..2]}, #{player.team&.short_name}) #{opponent}"
  end

  def format_last_gameweek(matches)
    return "No data" if matches.blank?

    last = matches.last
    return "No data" unless last

    stats = format_detailed_stats(last[:stats])
    "GW#{last[:gameweek]} - #{last[:points]}pts vs #{last[:opponent]}(#{last[:home_away]})#{stats}"
  end

  def format_recent_summary(matches)
    return "No recent data" if matches.blank?

    recent = matches.reverse
    return "Only 1 match played" if recent.size <= 1

    "#{summary_stats(recent)} - #{match_list(recent)}"
  end

  def summary_stats(matches)
    parts = [ "#{matches.sum { |m| m[:points] }}pts total" ]
    parts << stat_sum(matches, "goals_scored", "G")
    parts << stat_sum(matches, "assists", "A")
    parts << stat_count(matches, "clean_sheets", "CS")
    parts.compact.join(", ")
  end

  def stat_sum(matches, key, suffix)
    total = matches.sum { |m| m[:stats][key].to_i }
    "#{total}#{suffix}" if total.positive?
  end

  def stat_count(matches, key, suffix)
    count = matches.count { |m| m[:stats][key].to_f > 0 }
    "#{count}#{suffix}" if count.positive?
  end

  def match_list(matches)
    matches.first(4).map { |m| "GW#{m[:gameweek]}:#{m[:points]}pts(#{m[:opponent]})" }.join(", ")
  end

  def format_detailed_stats(stats)
    return "" if stats.blank?

    parts = detailed_stat_parts(stats)
    parts.any? ? " (#{parts.join(', ')})" : ""
  end

  def detailed_stat_parts(stats)
    [
      stat_if_positive(stats, "goals_scored") { |v| pluralize_stat(v, "goal") },
      stat_if_positive(stats, "assists") { |v| pluralize_stat(v, "assist") },
      stat_if_positive(stats, "clean_sheets") { "clean sheet" },
      stat_if_positive(stats, "saves") { |v| "#{v.to_i} saves" },
      stat_if_positive(stats, "bonus") { |v| "#{v.to_i} bonus" },
      conceded_stat(stats)
    ].compact
  end

  def stat_if_positive(stats, key)
    value = stats[key].to_f
    yield(value) if value.positive?
  end

  def conceded_stat(stats)
    "#{stats['goals_conceded'].to_i} conceded" if stats["goals_conceded"].to_f > 0 && stats["clean_sheets"].to_f == 0
  end

  def pluralize_stat(value, word)
    count = value.to_i
    "#{count} #{word}#{'s' if count != 1}"
  end

  def parse_response(response, forecasts)
    text = response.content&.first&.text&.strip
    return {} unless text

    json_text = extract_json(text)
    return {} unless json_text

    map_response_to_forecasts(JSON.parse(json_text), forecasts)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse batch explanation JSON: #{e.message}")
    {}
  end

  def map_response_to_forecasts(parsed, forecasts)
    forecasts.each_with_index.each_with_object({}) do |(forecast, idx), results|
      key = (idx + 1).to_s
      results[forecast.id] = parsed[key] if parsed[key]
    end
  end

  def extract_json(text)
    cleaned = text.gsub(/```json\s*/i, "").gsub(/```\s*/, "")
    start_idx = cleaned.index("{")
    return nil unless start_idx

    find_matching_brace(cleaned, start_idx)
  end

  def find_matching_brace(text, start_idx)
    depth = 0
    (start_idx...text.length).each do |i|
      depth += 1 if text[i] == "{"
      depth -= 1 if text[i] == "}"
      return text[start_idx..i] if depth.zero?
    end
    nil
  end

  def client
    @client ||= Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
  end
end
