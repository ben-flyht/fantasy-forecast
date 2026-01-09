require "test_helper"

class ExplanationGeneratorTest < ActiveSupport::TestCase
  def setup
    @player = players(:midfielder)
    @gameweek = gameweeks(:next_gw)

    @breakdown = {
      player: { name: "M.Salah", position: "midfielder", team: "LIV" },
      upcoming_fixture: { opponent: "CHE", home_away: "home" },
      recent_matches: [
        { gameweek: 19, points: 6, opponent: "ARS", home_away: "A", stats: { "goals_scored" => 1 } },
        { gameweek: 20, points: 10, opponent: "EVE", home_away: "H", stats: { "goals_scored" => 1, "assists" => 1, "bonus" => 3 } }
      ],
      performance: [
        { metric: "FPL points", weighted_average: 8.0, lookback: 3, recency: "none", weight: 1.0, context: [] }
      ],
      fixture_difficulty: [
        { metric: "team xG", weight: 0.5, value: 1.8 }
      ],
      availability: { chance_of_playing: 100, status: "fully fit" }
    }
  end

  test "returns nil when API key not present" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = nil

    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    assert_nil generator.call
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
  end

  test "tier_context returns empty string when no tier" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown,
      tier: nil
    )

    assert_equal "", generator.send(:tier_context)
  end

  test "tier_context returns formatted string for valid tier" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown,
      tier: 1
    )

    result = generator.send(:tier_context)

    assert_includes result, "Sunshine"
    assert_includes result, "must-start premium pick"
  end

  test "player_context includes player info and opponent" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    result = generator.send(:player_context)

    assert_includes result, "Mohamed Salah"
    assert_includes result, "midfielder"
    assert_includes result, "LIV"
    assert_includes result, "CHE"
  end

  test "recent_matches_context formats matches correctly" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    result = generator.send(:recent_matches_context)

    assert_includes result, "Recent matches"
    assert_includes result, "GW20"
    assert_includes result, "10pts"
    assert_includes result, "EVE"
    assert_includes result, "1G"
    assert_includes result, "1A"
    assert_includes result, "3B"
  end

  test "recent_matches_context returns empty when no matches" do
    @breakdown[:recent_matches] = []

    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    assert_equal "", generator.send(:recent_matches_context)
  end

  test "format_match_stats formats all stat types" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    stats = {
      "goals_scored" => 2,
      "assists" => 1,
      "clean_sheets" => 1,
      "saves" => 5,
      "bonus" => 3
    }

    result = generator.send(:format_match_stats, stats)

    assert_includes result, "2G"
    assert_includes result, "1A"
    assert_includes result, "CS"
    assert_includes result, "5 saves"
    assert_includes result, "3B"
  end

  test "format_match_stats returns empty for blank stats" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    assert_equal "", generator.send(:format_match_stats, {})
    assert_equal "", generator.send(:format_match_stats, nil)
  end

  test "conceded_part shows goals conceded without clean sheet" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    stats_with_conceded = { "goals_conceded" => 2, "clean_sheets" => 0 }
    stats_with_cs = { "goals_conceded" => 0, "clean_sheets" => 1 }

    assert_equal "2 conceded", generator.send(:conceded_part, stats_with_conceded)
    assert_nil generator.send(:conceded_part, stats_with_cs)
  end

  test "performance_context formats performance data" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    result = generator.send(:performance_context)

    assert_includes result, "Recent form"
    assert_includes result, "FPL points"
    assert_includes result, "8.0 avg"
    assert_includes result, "3GW"
  end

  test "performance_context returns empty when no performance data" do
    @breakdown[:performance] = []

    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    assert_equal "", generator.send(:performance_context)
  end

  test "fixture_context formats fixture difficulty" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    result = generator.send(:fixture_context)

    assert_includes result, "Fixture"
    assert_includes result, "team xG"
    assert_includes result, "1.8"
    assert_includes result, "50% weight"
  end

  test "fixture_context returns empty when no fixture data" do
    @breakdown[:fixture_difficulty] = nil

    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    assert_equal "", generator.send(:fixture_context)
  end

  test "availability_context shows doubt when not fully fit" do
    @breakdown[:availability] = { chance_of_playing: 75, status: "minor doubt" }

    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    result = generator.send(:availability_context)

    assert_includes result, "75%"
    assert_includes result, "minor doubt"
  end

  test "availability_context returns empty when fully fit" do
    @breakdown[:availability] = { chance_of_playing: 100, status: "fully fit" }

    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown
    )

    assert_equal "", generator.send(:availability_context)
  end

  test "build_prompt includes all context sections" do
    generator = ExplanationGenerator.new(
      player: @player,
      rank: 1,
      gameweek: @gameweek,
      breakdown: @breakdown,
      tier: 1
    )

    prompt = generator.send(:build_prompt)

    assert_includes prompt, "Mohamed Salah"
    assert_includes prompt, "Rank: #1"
    assert_includes prompt, "Sunshine"
    assert_includes prompt, "Recent matches"
    assert_includes prompt, "Recent form"
    assert_includes prompt, "Fixture"
    assert_includes prompt, "12 words max"
  end

  test "TIER_INFO contains all five tiers" do
    assert_equal 5, ExplanationGenerator::TIER_INFO.keys.length
    assert ExplanationGenerator::TIER_INFO[1][:name] == "Sunshine"
    assert ExplanationGenerator::TIER_INFO[5][:name] == "Snow"
  end
end
