require "test_helper"

class ScoringBreakdownTest < ActiveSupport::TestCase
  def setup
    @player = players(:midfielder)
    @goalkeeper = players(:goalkeeper)
    @next_gw = gameweeks(:next_gw)
    @finished_gw = gameweeks(:finished)
    @strategy_config = {
      performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ]
    }
  end

  test "returns player info" do
    result = ScoringBreakdown.new(player: @player, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_equal @player.short_name, result[:player][:name]
    assert_equal "midfielder", result[:player][:position]
    assert_equal teams(:liverpool).short_name, result[:player][:team]
  end

  test "returns upcoming fixture info when match exists" do
    result = ScoringBreakdown.new(player: @player, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_equal teams(:chelsea).short_name, result[:upcoming_fixture][:opponent]
    assert_equal "home", result[:upcoming_fixture][:home_away]
    assert_equal 1.8, result[:upcoming_fixture][:expected_goals_for]
    assert_equal 1.2, result[:upcoming_fixture][:expected_goals_against]
  end

  test "returns nil for upcoming fixture when no match exists" do
    team_no_match = Team.create!(fpl_id: 999, name: "No Match FC", short_name: "NMF")
    player_no_match = Player.create!(fpl_id: 9999, first_name: "No", last_name: "Match", position: "midfielder", team: team_no_match)

    result = ScoringBreakdown.new(player: player_no_match, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_nil result[:upcoming_fixture]
  end

  test "returns recent match history with performance data" do
    result = ScoringBreakdown.new(player: @player, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_equal 1, result[:recent_matches].length

    match = result[:recent_matches].first
    assert_equal @finished_gw.fpl_id, match[:gameweek]
    assert_equal teams(:arsenal).short_name, match[:opponent]
    assert_equal "H", match[:home_away]
    assert_equal 10, match[:points]
    assert_equal 1, match[:stats]["goals_scored"]
    assert_equal 1, match[:stats]["assists"]
  end

  test "excludes matches without performance data" do
    player = players(:midfielder_two)

    result = ScoringBreakdown.new(player: player, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_empty result[:recent_matches]
  end

  test "returns availability info" do
    result = ScoringBreakdown.new(player: @goalkeeper, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_equal 75, result[:availability][:chance_of_playing]
    assert_equal "minor doubt", result[:availability][:status]
  end

  test "returns fully fit when no availability data" do
    result = ScoringBreakdown.new(player: @player, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_equal 100, result[:availability][:chance_of_playing]
    assert_equal "fully fit", result[:availability][:status]
  end

  test "returns correct availability status for each threshold" do
    test_cases = [
      { chance: 100, status: "fully fit" },
      { chance: 75, status: "minor doubt" },
      { chance: 50, status: "doubtful" },
      { chance: 25, status: "major doubt" },
      { chance: 10, status: "unlikely to play" },
      { chance: 0, status: "ruled out" }
    ]

    test_cases.each_with_index do |tc, idx|
      # Create fresh player each iteration to avoid cached associations
      player = Player.create!(fpl_id: 99900 + idx, first_name: "Test", last_name: "Player#{idx}", position: "midfielder", team: teams(:chelsea))
      Statistic.create!(player: player, gameweek: @next_gw, type: "chance_of_playing", value: tc[:chance]) unless tc[:chance] == 100

      result = ScoringBreakdown.new(player: player, strategy_config: @strategy_config, gameweek: @next_gw).call

      assert_equal tc[:status], result[:availability][:status], "Expected status '#{tc[:status]}' for chance #{tc[:chance]}"
    end
  end

  test "returns performance breakdown from strategy config" do
    Statistic.create!(player: @player, gameweek: @finished_gw, type: "total_points", value: 10)

    result = ScoringBreakdown.new(player: @player, strategy_config: @strategy_config, gameweek: @next_gw).call

    assert_equal 1, result[:performance].length
    perf = result[:performance].first
    assert_equal "FPL points", perf[:metric]
    assert_equal 1.0, perf[:weight]
    assert_equal 3, perf[:lookback]
  end

  test "extracts position-relevant stats for goalkeeper" do
    result = ScoringBreakdown.new(player: @goalkeeper, strategy_config: @strategy_config, gameweek: @next_gw).call

    stats = result[:recent_matches].first[:stats]
    assert_equal 1, stats["clean_sheets"]
    assert_equal 5, stats["saves"]
  end

  test "includes in-progress gameweeks that have started" do
    in_progress_gw = Gameweek.create!(
      fpl_id: 19,
      name: "Gameweek 19",
      start_time: 1.day.ago,
      is_finished: false,
      is_current: true
    )

    Match.create!(fpl_id: 999, gameweek: in_progress_gw, home_team: teams(:liverpool), away_team: teams(:arsenal))
    Performance.create!(player: @player, gameweek: in_progress_gw, team: teams(:liverpool), gameweek_score: 12)

    result = ScoringBreakdown.new(player: @player, strategy_config: @strategy_config, gameweek: @next_gw).call

    gameweeks = result[:recent_matches].map { |m| m[:gameweek] }
    assert_includes gameweeks, 19
  end
end
