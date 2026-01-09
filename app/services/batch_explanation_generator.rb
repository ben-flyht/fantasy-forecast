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

    # Handle Snow tier with simple fallback (no AI needed)
    snow_forecasts, other_forecasts = partition_by_tier

    snow_forecasts.each do |forecast|
      results[forecast.id] = snow_tier_explanation(forecast)
    end

    # Batch AI call for tiers 1-4
    if other_forecasts.any?
      ai_results = generate_batch_explanations(other_forecasts)
      results.merge!(ai_results)
    end

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

    percentage_from_top = ((top_score - forecast.score) / top_score.to_f) * 100

    case percentage_from_top
    when -Float::INFINITY..20 then 1
    when 20..40 then 2
    when 40..60 then 3
    when 60..80 then 4
    else SNOW_TIER
    end
  end

  def snow_tier_explanation(forecast)
    player = forecast.player
    chance = player.chance_of_playing(@gameweek)
    news = player.news

    # Use FPL news if available, otherwise fall back to generic message
    if news.present?
      truncate_news(news)
    else
      case chance
      when 0 then "Ruled out."
      when 1..49 then "Unlikely to play."
      when 50..74 then "Fitness doubt."
      else nil # Low tier but available - no explanation needed
      end
    end
  end

  def truncate_news(news)
    # Keep it concise - truncate to ~60 chars if needed
    news.length > 60 ? "#{news[0, 57]}..." : news
  end

  def generate_batch_explanations(forecasts)
    breakdowns = build_breakdowns(forecasts)
    prompt = build_batch_prompt(forecasts, breakdowns)

    response = client.messages.create(
      model: MODEL,
      max_tokens: 8000,
      messages: [{ role: "user", content: prompt }]
    )

    parse_response(response, forecasts)
  rescue Anthropic::APIError => e
    Rails.logger.error("Anthropic API error in batch generation: #{e.message}")
    {}
  rescue StandardError => e
    Rails.logger.error("Batch explanation generation failed: #{e.message}")
    {}
  end

  def build_breakdowns(forecasts)
    forecasts.each_with_object({}) do |forecast, hash|
      config = position_config(forecast.player.position)
      hash[forecast.id] = ScoringBreakdown.new(
        player: forecast.player,
        strategy_config: config,
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

    <<~PROMPT
      Generate 2-sentence explanations for each player's FPL ranking.

      Sentence 1: Recent form - reference SPECIFIC gameweeks and matches (e.g., "Scored twice vs Newcastle in GW21, just 1 goal in previous 3 games.")
      Sentence 2: Fixture outlook - mention the upcoming opponent specifically (e.g., "Faces leaky Wolves who conceded 8 in last 4.")

      IMPORTANT: Use the gameweek numbers provided (GW20, GW21, etc.) to give temporal context.
      Be specific with stats and opponent names. Avoid generic phrases like "good form" or "favourable fixture".

      #{player_lines.join("\n\n")}

      Return ONLY valid JSON with player numbers as keys:
      {"1": "Two sentence explanation here.", "2": "Two sentence explanation here.", ...}
    PROMPT
  end

  def build_player_line(number, forecast, breakdown)
    player = forecast.player
    fixture = breakdown[:upcoming_fixture]
    matches = breakdown[:recent_matches] || []

    opponent_info = fixture ? "vs #{fixture[:opponent]}(#{fixture[:home_away][0].upcase})" : ""
    last_gw_detail = format_last_gameweek(matches)
    recent_summary = format_recent_summary(matches)

    <<~LINE.strip
      #{number}. #{player.short_name} ##{forecast.rank} (#{player.position.upcase[0..2]}, #{player.team&.short_name}) #{opponent_info}
         Last GW: #{last_gw_detail}
         Form (last 5): #{recent_summary}
    LINE
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

    # Skip the last one since we detail it separately
    recent = matches.reverse
    return "Only 1 match played" if recent.size <= 1

    total_pts = recent.map { |m| m[:points] }.sum
    goals = recent.sum { |m| m[:stats]["goals_scored"].to_i }
    assists = recent.sum { |m| m[:stats]["assists"].to_i }
    clean_sheets = recent.count { |m| m[:stats]["clean_sheets"].to_f > 0 }

    parts = ["#{total_pts}pts total"]
    parts << "#{goals}G" if goals > 0
    parts << "#{assists}A" if assists > 0
    parts << "#{clean_sheets}CS" if clean_sheets > 0

    match_list = recent.first(4).map { |m| "GW#{m[:gameweek]}:#{m[:points]}pts(#{m[:opponent]})" }.join(", ")
    "#{parts.join(', ')} - #{match_list}"
  end

  def format_detailed_stats(stats)
    return "" if stats.blank?

    parts = []
    parts << "#{stats['goals_scored'].to_i} goal#{'s' if stats['goals_scored'].to_i != 1}" if stats["goals_scored"].to_f > 0
    parts << "#{stats['assists'].to_i} assist#{'s' if stats['assists'].to_i != 1}" if stats["assists"].to_f > 0
    parts << "clean sheet" if stats["clean_sheets"].to_f > 0
    parts << "#{stats['saves'].to_i} saves" if stats["saves"].to_f > 0
    parts << "#{stats['bonus'].to_i} bonus" if stats["bonus"].to_f > 0
    parts << "#{stats['goals_conceded'].to_i} conceded" if stats["goals_conceded"].to_f > 0 && stats["clean_sheets"].to_f == 0

    parts.any? ? " (#{parts.join(', ')})" : ""
  end

  def format_stats(stats)
    return "" if stats.blank?

    parts = []
    parts << "#{stats['goals_scored'].to_i}G" if stats["goals_scored"].to_f > 0
    parts << "#{stats['assists'].to_i}A" if stats["assists"].to_f > 0
    parts << "CS" if stats["clean_sheets"].to_f > 0
    parts << "#{stats['saves'].to_i}sv" if stats["saves"].to_f > 0

    parts.any? ? " [#{parts.join(',')}]" : ""
  end

  def parse_response(response, forecasts)
    text = response.content&.first&.text&.strip
    return {} unless text

    # Extract JSON from response (handle markdown code blocks and multiline)
    # Try to find JSON object that spans multiple lines
    json_text = extract_json(text)
    return {} unless json_text

    parsed = JSON.parse(json_text)

    # Map numbered responses back to forecast IDs
    forecasts.each_with_index.each_with_object({}) do |(forecast, idx), results|
      key = (idx + 1).to_s
      results[forecast.id] = parsed[key] if parsed[key]
    end
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse batch explanation JSON: #{e.message}")
    Rails.logger.error("Response text: #{text[0, 500]}")
    {}
  end

  def extract_json(text)
    # Remove markdown code blocks if present
    cleaned = text.gsub(/```json\s*/i, "").gsub(/```\s*/, "")

    # Find the JSON object (handles multiline)
    start_idx = cleaned.index("{")
    return nil unless start_idx

    # Find matching closing brace
    depth = 0
    (start_idx...cleaned.length).each do |i|
      depth += 1 if cleaned[i] == "{"
      depth -= 1 if cleaned[i] == "}"
      return cleaned[start_idx..i] if depth.zero?
    end

    nil
  end

  def client
    @client ||= Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
  end

  def api_key_present?
    ENV["ANTHROPIC_API_KEY"].present?
  end
end
