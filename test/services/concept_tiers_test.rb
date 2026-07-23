require "test_helper"

class ConceptTiersTest < ActiveSupport::TestCase
  def ranking(player_id, score:, position: "midfielder", team_id: 1)
    ConsensusRanking::Ranking.new(player_id: player_id, position: position, team_id: team_id, score: score)
  end

  test "quality tiers rank a high per-90 midfielder above a low one" do
    rankings = [ ranking(1, score: 100), ranking(2, score: 90) ]
    stats = {
      1 => { "expected_goal_involvements_per_90" => 0.9 },
      2 => { "expected_goal_involvements_per_90" => 0.1 }
    }

    result = ConceptTiers.new(rankings, stats: stats, difficulty_by_team: {}).call

    assert_equal 1, result[1][:quality]
    assert result[2][:quality] > result[1][:quality]
  end

  test "set-piece duty lifts the quality score" do
    rankings = [ ranking(1, score: 100), ranking(2, score: 100) ]
    stats = {
      1 => { "expected_goal_involvements_per_90" => 0.5, "penalties_order" => 1 },
      2 => { "expected_goal_involvements_per_90" => 0.5 }
    }

    result = ConceptTiers.new(rankings, stats: stats, difficulty_by_team: {}).call

    # Penalty taker tops the tier; the other falls below it
    assert_equal 1, result[1][:quality]
    assert result[2][:quality] > 1
  end

  test "schedule rewards an easier fixture and is bottom tier with no fixture" do
    rankings = [ ranking(1, score: 100, team_id: 10), ranking(2, score: 100, team_id: 20), ranking(3, score: 100, team_id: 30) ]

    result = ConceptTiers.new(rankings, stats: {}, difficulty_by_team: { 10 => 2.0, 20 => 5.0 }).call

    assert_equal 1, result[1][:schedule], "easy fixture (FDR 2) is top tier"
    assert result[2][:schedule] > result[1][:schedule], "hard fixture (FDR 5) is worse"
    assert_equal 5, result[3][:schedule], "no fixture is bottom tier"
  end

  test "differential flags an under-owned player we rate highly as a gem" do
    rankings = [ ranking(1, score: 100), ranking(2, score: 100) ]
    stats = {
      1 => { "selected_by_percent" => 3.0 },   # we rate highly, crowd does not
      2 => { "selected_by_percent" => 55.0 }   # popular
    }

    result = ConceptTiers.new(rankings, stats: stats, difficulty_by_team: {}).call

    assert result[1][:gem], "under-owned strong pick is a gem"
    assert_not result[2][:gem], "popular pick is not a gem"
    assert result[1][:differential] < result[2][:differential], "gem has the stronger differential tier"
  end

  test "a player owned by nobody yet is not flagged (avoids brand-new noise)" do
    rankings = [ ranking(1, score: 100) ]
    stats = { 1 => { "selected_by_percent" => 0.0 } }

    result = ConceptTiers.new(rankings, stats: stats, difficulty_by_team: {}).call

    assert_not result[1][:gem]
  end
end
