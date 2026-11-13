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

    test "keeps every Play pack, archived with its cards and points, and frees it from the gameweek" do
      gameweek = gameweeks(:finished)
      cards = [ players(:goalkeeper), players(:midfielder), players(:midfielder_two), players(:brazilian) ]
      { cards[0] => 6, cards[1] => 2, cards[2] => 9, cards[3] => 1 }.each do |player, points|
        Performance.find_or_initialize_by(player: player, gameweek: gameweek).update!(team: player.team, gameweek_score: points)
      end
      offered = cards.each_slice(2).with_index.map do |pair, index|
        { "slot" => Pack::SLOTS[index], "shiny" => index == 1,
          "cards" => pair.map { |player| { "player_id" => player.id, "rank" => 1, "expected_points" => 4.0, "fixtures" => [] } } }
      end
      user = User.create!(email: "kept@example.com", username: "Kept")
      selection = Selection.new(user: user, gameweek: gameweek, offered: offered, picks: "ab", season: Season.current, gameweek_number: gameweek.fpl_id)
      selection.save!(validate: false)

      Fpl::ResetSeason.call

      selection.reload
      assert_nil selection.gameweek_id
      assert_equal gameweek.fpl_id, selection.gameweek_number
      assert_equal 6 + (1 * 2), selection.archive["points"], "goalkeeper, then the Brazilian as captain"
      assert_equal [ 6, 2 ], selection.archive["hand"].first["cards"].map { |card| card["points"] }
      assert_equal players(:goalkeeper).display_name, selection.archive["hand"].first["cards"].first["player"]
      assert_equal [ 0, 1 ], selection.archive["hand"].map { |pair| pair["kept"] }
      assert_equal 1, Selection.count
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
