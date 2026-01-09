require "test_helper"

class BatchExplanationGeneratorTest < ActiveSupport::TestCase
  def setup
    @next_gw = gameweeks(:next_gw)
    @forecasts = [ forecasts(:top_ranked), forecasts(:second_ranked) ]
    @strategy_config = {
      performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ]
    }
  end

  test "returns empty hash for empty forecasts" do
    result = BatchExplanationGenerator.new(
      forecasts: [],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    ).call

    assert_equal({}, result)
  end

  test "partitions forecasts by tier" do
    snow_forecast = forecasts(:snow_tier)

    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts + [ snow_forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    snow, other = generator.send(:partition_by_tier)

    assert_equal 1, snow.length
    assert_equal snow_forecast.id, snow.first.id
    assert_equal 2, other.length
  end

  test "calculates correct tier from percentage" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    assert_equal 1, generator.send(:tier_from_percentage, 10)
    assert_equal 2, generator.send(:tier_from_percentage, 30)
    assert_equal 3, generator.send(:tier_from_percentage, 50)
    assert_equal 4, generator.send(:tier_from_percentage, 70)
    assert_equal 5, generator.send(:tier_from_percentage, 90)
  end

  test "snow tier explanation uses player news when available" do
    forecast = forecasts(:snow_tier)

    generator = BatchExplanationGenerator.new(
      forecasts: [ forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    explanation = generator.send(:snow_tier_explanation, forecast)

    assert_equal "Hamstring injury - Expected back 15 Jan", explanation
  end

  test "snow tier explanation truncates long news" do
    player = players(:injured_player)
    player.update!(news: "This is a very long news string that exceeds sixty characters and should be truncated")

    forecast = forecasts(:snow_tier)

    generator = BatchExplanationGenerator.new(
      forecasts: [ forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    explanation = generator.send(:snow_tier_explanation, forecast)

    assert explanation.length <= 60
    assert explanation.end_with?("...")
  end

  test "snow tier explanation falls back to availability message" do
    player = players(:injured_player)
    player.update!(news: nil)

    forecast = forecasts(:snow_tier)

    generator = BatchExplanationGenerator.new(
      forecasts: [ forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    explanation = generator.send(:snow_tier_explanation, forecast)

    assert_equal "Ruled out.", explanation
  end

  test "availability explanation returns correct messages" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    assert_equal "Ruled out.", generator.send(:availability_explanation, 0)
    assert_equal "Unlikely to play.", generator.send(:availability_explanation, 25)
    assert_equal "Fitness doubt.", generator.send(:availability_explanation, 50)
    assert_nil generator.send(:availability_explanation, 100)
  end

  test "format_last_gameweek returns No data when empty" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    assert_equal "No data", generator.send(:format_last_gameweek, [])
    assert_equal "No data", generator.send(:format_last_gameweek, nil)
  end

  test "format_last_gameweek formats match data correctly" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    match_data = {
      gameweek: 20,
      points: 8,
      opponent: "ARS",
      home_away: "H",
      stats: { "goals_scored" => 1, "assists" => 1 }
    }

    result = generator.send(:format_last_gameweek, [ match_data ])

    assert_includes result, "GW20"
    assert_includes result, "8pts"
    assert_includes result, "ARS"
    assert_includes result, "(H)"
  end

  test "format_recent_summary returns No recent data when empty" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    assert_equal "No recent data", generator.send(:format_recent_summary, [])
  end

  test "format_recent_summary returns Only 1 match played for single match" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    single_match = [ { gameweek: 20, points: 8, opponent: "ARS", home_away: "H", stats: {} } ]

    assert_equal "Only 1 match played", generator.send(:format_recent_summary, single_match)
  end

  test "summary_stats aggregates correctly" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    matches = [
      { points: 10, stats: { "goals_scored" => 2, "assists" => 1 } },
      { points: 5, stats: { "goals_scored" => 0, "assists" => 1 } }
    ]

    result = generator.send(:summary_stats, matches)

    assert_includes result, "15pts total"
    assert_includes result, "2G"
    assert_includes result, "2A"
  end

  test "extract_json handles markdown code blocks" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    text_with_markdown = "```json\n{\"1\": \"test\"}\n```"

    result = generator.send(:extract_json, text_with_markdown)

    assert_equal "{\"1\": \"test\"}", result
  end

  test "extract_json handles plain JSON" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    plain_json = "{\"1\": \"test\", \"2\": \"test2\"}"

    result = generator.send(:extract_json, plain_json)

    assert_equal plain_json, result
  end

  test "map_response_to_forecasts maps correctly" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    parsed = { "1" => "First explanation", "2" => "Second explanation" }

    result = generator.send(:map_response_to_forecasts, parsed, @forecasts)

    assert_equal "First explanation", result[@forecasts[0].id]
    assert_equal "Second explanation", result[@forecasts[1].id]
  end

  test "pluralize_stat handles singular and plural" do
    generator = BatchExplanationGenerator.new(
      forecasts: @forecasts,
      gameweek: @next_gw,
      strategy_config: @strategy_config
    )

    assert_equal "1 goal", generator.send(:pluralize_stat, 1, "goal")
    assert_equal "2 goals", generator.send(:pluralize_stat, 2, "goal")
    assert_equal "1 assist", generator.send(:pluralize_stat, 1, "assist")
    assert_equal "3 assists", generator.send(:pluralize_stat, 3, "assist")
  end
end
