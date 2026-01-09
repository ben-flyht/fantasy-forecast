# Generates AI-powered explanations for player rankings using Claude
class ExplanationGenerator
  class GenerationError < StandardError; end

  MAX_TOKENS = 60
  MODEL = "claude-3-5-haiku-latest".freeze

  TIER_INFO = {
    1 => { name: "Sunshine", description: "must-start premium pick" },
    2 => { name: "Partly Cloudy", description: "strong reliable option" },
    3 => { name: "Cloudy", description: "solid but higher variance" },
    4 => { name: "Rainy", description: "risky, proceed with caution" },
    5 => { name: "Snow", description: "avoid - loss/injury risk" }
  }.freeze

  def initialize(player:, rank:, gameweek:, breakdown:, tier: nil)
    @player = player
    @rank = rank
    @gameweek = gameweek
    @breakdown = breakdown
    @tier = tier
  end

  def call
    return nil unless api_key_present?

    response = call_api
    extract_text(response)
  rescue Anthropic::APIError, StandardError => e
    Rails.logger.error("Explanation generation failed for #{@player.short_name}: #{e.message}")
    nil
  end

  private

  def call_api
    client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: [ { role: "user", content: build_prompt } ]
    )
  end

  def client
    @client ||= Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
  end

  def api_key_present?
    ENV["ANTHROPIC_API_KEY"].present?
  end

  def extract_text(response)
    response.content&.first&.text&.strip
  end

  def build_prompt
    <<~PROMPT
      You are an FPL ranking assistant. Write a 12-word max explanation for this player's ranking.

      #{player_context}
      Rank: ##{@rank}#{tier_context}
      #{recent_matches_context}
      #{performance_context}
      #{fixture_context}
      #{availability_context}

      IMPORTANT: Reference SPECIFIC recent matches by opponent name (e.g., "6 saves vs Liverpool", "scored vs Arsenal").
      Avoid generic phrases like "clean sheet potential" or "home advantage". Be specific.

      Output ONLY the explanation (12 words max). Examples:
      - "8 saves vs Liverpool last week, only 1 clean sheet in 5 though."
      - "Scored in 3 of last 5, including brace vs Newcastle."
      - "Just 2 pts vs Wolves, but 11 pts at home vs Brighton before."
    PROMPT
  end

  def tier_context
    return "" unless @tier && TIER_INFO[@tier]

    info = TIER_INFO[@tier]
    " (#{info[:name]} tier - #{info[:description]})"
  end

  def player_context
    info = @breakdown[:player]
    fixture = @breakdown[:upcoming_fixture]

    lines = [ "Player: #{@player.full_name} (#{info[:position]}, #{info[:team]})" ]
    lines << "Opponent: #{fixture[:opponent]} (#{fixture[:home_away]})" if fixture
    lines.join("\n")
  end

  def recent_matches_context
    matches = @breakdown[:recent_matches]
    return "" if matches.blank?

    lines = [ "Recent matches (most recent first):" ]
    matches.reverse.each { |match| lines << format_match_line(match) }
    lines.join("\n")
  end

  def format_match_line(match)
    line = "- GW#{match[:gameweek]}: #{match[:points]}pts vs #{match[:opponent]}(#{match[:home_away]})"
    stats_str = format_match_stats(match[:stats])
    stats_str.present? ? "#{line} [#{stats_str}]" : line
  end

  def format_match_stats(stats)
    return "" if stats.blank?

    build_stat_parts(stats).join(", ")
  end

  def build_stat_parts(stats)
    [
      stat_part(stats, "goals_scored", "G"),
      stat_part(stats, "assists", "A"),
      ("CS" if stats["clean_sheets"].to_f > 0),
      stat_part(stats, "saves", " saves"),
      stat_part(stats, "bonus", "B"),
      conceded_part(stats)
    ].compact
  end

  def stat_part(stats, key, suffix)
    value = stats[key].to_i
    "#{value}#{suffix}" if stats[key].to_f > 0
  end

  def conceded_part(stats)
    "#{stats['goals_conceded'].to_i} conceded" if stats["goals_conceded"].to_f > 0 && stats["clean_sheets"].to_f == 0
  end

  def performance_context
    return "" if @breakdown[:performance].blank?

    lines = [ "Recent form:" ]
    @breakdown[:performance].each { |perf| add_performance_lines(perf, lines) }
    lines.join("\n")
  end

  def add_performance_lines(perf, lines)
    lines << format_perf_line(perf)
    lines << format_highlights(perf[:context]) if perf[:context].present?
  end

  def format_perf_line(perf)
    "- #{perf[:metric]}: #{perf[:weighted_average]} avg (#{perf[:lookback]}GW, #{perf[:recency]} weighting, #{(perf[:weight] * 100).to_i}% weight)"
  end

  def format_highlights(context)
    highlights = context.map { |c| "#{c[:value].to_i} vs #{c[:opponent]}(#{c[:home_away]})" }
    "  Notable: #{highlights.join(', ')}" if highlights.any?
  end

  def fixture_context
    return "" if @breakdown[:fixture_difficulty].blank?
    return "" unless @breakdown[:upcoming_fixture]

    lines = [ "Fixture:" ]
    @breakdown[:fixture_difficulty].each do |fd|
      lines << "- #{fd[:metric]}: #{fd[:value]} (#{(fd[:weight] * 100).to_i}% weight)"
    end
    lines.join("\n")
  end

  def availability_context
    avail = @breakdown[:availability]
    return "" unless avail && avail[:chance_of_playing] < 100

    "Availability: #{avail[:chance_of_playing]}% chance of playing (#{avail[:status]})"
  end
end
