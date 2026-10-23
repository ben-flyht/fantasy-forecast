require "test_helper"

module History
  class OddsTest < ActiveSupport::TestCase
    test "even odds and an even goal line give two even sides" do
      home, away = Odds.implied_goals(home_win: 2.9, draw: 3.4, away_win: 2.9, over: 2.0, under: 2.0)

      assert_in_delta home, away, 0.01
      assert_in_delta 2.67, home + away, 0.05
    end

    test "the favourite is expected to score more, and a high goal line means more goals" do
      home, away = Odds.implied_goals(home_win: 1.3, draw: 6.0, away_win: 10.0, over: 1.5, under: 2.6)
      quieter = Odds.implied_goals(home_win: 1.3, draw: 6.0, away_win: 10.0, over: 2.4, under: 1.6)

      assert_operator home, :>, 2 * away
      assert_operator home + away, :>, quieter.sum
    end

    test "the implied goals reproduce the market's prices" do
      home, away = Odds.implied_goals(home_win: 1.8, draw: 3.8, away_win: 4.5, over: 1.7, under: 2.2)
      win, _, loss = Odds.fair([ 1.8, 3.8, 4.5 ])

      assert_in_delta win - loss, Odds.margin(home, away), 0.001
    end

    test "football-data's names are matched to FPL's" do
      odds = Odds.new([ { "HomeTeam" => "Man United", "AwayTeam" => "Tottenham", "AvgH" => "2.0", "AvgD" => "3.5",
                          "AvgA" => "3.8", "Avg>2.5" => "1.8", "Avg<2.5" => "2.0", "FTHG" => "2", "FTAG" => "1" } ])

      assert odds.expected_goals("Man Utd", "Spurs")
      assert_nil odds.expected_goals("Spurs", "Man Utd")
    end
  end
end
