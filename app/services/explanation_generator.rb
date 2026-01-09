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

    response = client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: [ { role: "user", content: build_prompt } ]
    )

    extract_text(response)
  rescue Anthropic::APIError => e
    Rails.logger.error("Anthropic API error for #{@player.short_name}: #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.error("Explanation generation failed for #{@player.short_name}: #{e.message}")
    nil
  end

  private

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

    matches.reverse.each do |match|
      stats_str = format_match_stats(match[:stats])
      line = "- GW#{match[:gameweek]}: #{match[:points]}pts vs #{match[:opponent]}(#{match[:home_away]})"
      line += " [#{stats_str}]" if stats_str.present?
      lines << line
    end

    lines.join("\n")
  end

  def format_match_stats(stats)
    return "" if stats.blank?

    parts = []
    parts << "#{stats['goals_scored'].to_i}G" if stats["goals_scored"].to_f > 0
    parts << "#{stats['assists'].to_i}A" if stats["assists"].to_f > 0
    parts << "CS" if stats["clean_sheets"].to_f > 0
    parts << "#{stats['saves'].to_i} saves" if stats["saves"].to_f > 0
    parts << "#{stats['bonus'].to_i}B" if stats["bonus"].to_f > 0
    parts << "#{stats['goals_conceded'].to_i} conceded" if stats["goals_conceded"].to_f > 0 && stats["clean_sheets"].to_f == 0

    parts.join(", ")
  end

  def performance_context
    return "" if @breakdown[:performance].blank?

    lines = [ "Recent form:" ]

    @breakdown[:performance].each do |perf|
      line = "- #{perf[:metric]}: #{perf[:weighted_average]} avg (#{perf[:lookback]}GW, #{perf[:recency]} weighting, #{(perf[:weight] * 100).to_i}% weight)"
      lines << line

      if perf[:context].present?
        highlights = perf[:context].map { |c| "#{c[:value].to_i} vs #{c[:opponent]}(#{c[:home_away]})" }
        lines << "  Notable: #{highlights.join(', ')}" if highlights.any?
      end
    end

    lines.join("\n")
  end

  def fixture_context
    return "" if @breakdown[:fixture_difficulty].blank?

    fixture = @breakdown[:upcoming_fixture]
    return "" unless fixture

    lines = [ "Fixture:" ]
    @breakdown[:fixture_difficulty].each do |fd|
      lines << "- #{fd[:metric]}: #{fd[:value]} (#{(fd[:weight] * 100).to_i}% weight)"
    end

    lines.join("\n")
  end

  def availability_context
    avail = @breakdown[:availability]
    return "" unless avail

    if avail[:chance_of_playing] < 100
      "Availability: #{avail[:chance_of_playing]}% chance of playing (#{avail[:status]})"
    else
      ""
    end
  end
end
