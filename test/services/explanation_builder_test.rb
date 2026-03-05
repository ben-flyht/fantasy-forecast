require "test_helper"

class ExplanationBuilderTest < ActiveSupport::TestCase
  def setup
    @next_gw = gameweeks(:next_gw)
    @strategy_config = {
      performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ]
    }
  end

  test "returns empty hash for empty forecasts" do
    result = ExplanationBuilder.new(forecasts: [], gameweek: @next_gw, strategy_config: @strategy_config).call
    assert_equal({}, result)
  end

  test "generates explanation with performance and fixture" do
    forecast = forecasts(:top_ranked)

    result = ExplanationBuilder.new(
      forecasts: [ forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    ).call

    explanation = result[forecast.id]
    assert_includes explanation, "Averaging"
    assert_includes explanation, "over the last 3 matches"
    assert_includes explanation, "M.Salah faces Chelsea"
  end

  test "joins multiple metrics with and" do
    config = {
      performance: [
        { metric: "total_points", weight: 0.5, lookback: 5, recency: "none" },
        { metric: "goals_scored", weight: 0.5, lookback: 5, recency: "none" }
      ]
    }
    forecast = forecasts(:top_ranked)

    result = ExplanationBuilder.new(
      forecasts: [ forecast ],
      gameweek: @next_gw,
      strategy_config: config
    ).call

    assert_includes result[forecast.id], "FPL points and"
    assert_includes result[forecast.id], "over the last 5 matches"
  end

  test "includes fixture xG with lookback" do
    forecast = forecasts(:top_ranked)
    config = @strategy_config.merge(fixture: [ { metric: "expected_goals_for", weight: 0.3, lookback: 6 } ])

    result = ExplanationBuilder.new(
      forecasts: [ forecast ],
      gameweek: @next_gw,
      strategy_config: config
    ).call

    explanation = result[forecast.id]
    assert_includes explanation, "faces Chelsea"
    assert_includes explanation, "who have allowed"
    assert_includes explanation, "team xG"
    assert_includes explanation, "over the last 6 matches"
  end

  test "snow tier uses player news when available" do
    forecast = forecasts(:snow_tier)

    result = ExplanationBuilder.new(
      forecasts: [ forecasts(:top_ranked), forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    ).call

    assert_equal "Hamstring injury - Expected back 15 Jan", result[forecast.id]
  end

  test "snow tier truncates long news" do
    players(:injured_player).update!(news: "This is a very long news string that exceeds sixty characters and should be truncated")
    forecast = forecasts(:snow_tier)

    result = ExplanationBuilder.new(
      forecasts: [ forecasts(:top_ranked), forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    ).call

    assert result[forecast.id].length <= 60
    assert result[forecast.id].end_with?("...")
  end

  test "snow tier falls back to availability when no news" do
    players(:injured_player).update!(news: nil)
    forecast = forecasts(:snow_tier)

    result = ExplanationBuilder.new(
      forecasts: [ forecasts(:top_ranked), forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    ).call

    assert_equal "Ruled out.", result[forecast.id]
  end

  test "includes availability when not fully fit" do
    forecast = forecasts(:top_ranked)
    Statistic.create!(player: forecast.player, gameweek: @next_gw, type: "chance_of_playing", value: 75)

    result = ExplanationBuilder.new(
      forecasts: [ forecast ],
      gameweek: @next_gw,
      strategy_config: @strategy_config
    ).call

    assert_includes result[forecast.id], "75% chance of playing (minor doubt)"
  end
end
