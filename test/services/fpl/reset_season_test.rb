require "test_helper"

module Fpl
  class ResetSeasonTest < ActiveSupport::TestCase
    test "deletes every FPL table, in a foreign-key-safe order" do
      assert_predicate Team.count, :positive?
      assert_predicate Player.count, :positive?
      assert_predicate Gameweek.count, :positive?

      Fpl::ResetSeason.call

      assert_equal 0, Team.count
      assert_equal 0, Player.count
      assert_equal 0, Gameweek.count
      assert_equal 0, Match.count
      assert_equal 0, Performance.count
      assert_equal 0, Statistic.count
      assert_equal 0, Forecast.count
    end

    test "takes the payload archive with it, rather than tripping over it" do
      Payload.create!(kind: Payload::EVENT, fpl_id: 21, gameweek: gameweeks(:next_gw), data: { "ranked_count" => 10 })

      Fpl::ResetSeason.call

      assert_equal 0, Payload.count
      assert_equal 0, Gameweek.count
    end

    test "keeps tuned strategies" do
      strategies = Strategy.count
      assert_predicate strategies, :positive?

      Fpl::ResetSeason.call

      assert_equal strategies, Strategy.count
    end

    test "returns the number of rows deleted per table" do
      teams = Team.count

      result = Fpl::ResetSeason.call

      assert_equal teams, result["teams"]
      assert_kind_of Integer, result["forecasts"]
    end
  end
end
