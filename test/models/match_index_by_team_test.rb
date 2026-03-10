require "test_helper"

class MatchIndexByTeamTest < ActiveSupport::TestCase
  def setup
    Forecast.delete_all
    Statistic.delete_all
    Performance.delete_all
    Match.delete_all
    Gameweek.delete_all

    @gw = Gameweek.create!(fpl_id: 800, name: "Gameweek 800", start_time: 1.week.ago, is_finished: true)
    @arsenal = teams(:arsenal)
    @chelsea = teams(:chelsea)
    @liverpool = teams(:liverpool)

    @match1 = Match.create!(fpl_id: 8001, home_team: @arsenal, away_team: @chelsea, gameweek: @gw)
    @match2 = Match.create!(fpl_id: 8002, home_team: @liverpool, away_team: @arsenal, gameweek: @gw)
  end

  test "home team maps to its match" do
    index = Match.where(fpl_id: 8001).index_by_team

    assert_equal @match1, index[@arsenal.id]
  end

  test "away team maps to its match" do
    index = Match.where(fpl_id: 8001).index_by_team

    assert_equal @match1, index[@chelsea.id]
  end

  test "returns empty hash for no matches" do
    index = Match.none.index_by_team

    assert_equal({}, index)
  end

  test "later match overwrites earlier for same team" do
    index = Match.where(gameweek: @gw).index_by_team

    assert_equal @match2, index[@arsenal.id]
  end
end
