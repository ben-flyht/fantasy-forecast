require "test_helper"

class PlayersHelperTest < ActionView::TestCase
  include ApplicationHelper

  setup do
    @player = players(:midfielder)
    @forecast = { score: 6.25, grade: "B+", horizon: "gameweek", gameweek: 8 }
    @stats = { "now_cost" => 145, "selected_by_percent" => 41.2 }
  end

  test "a forecast player's title names the gameweek he is predicted for" do
    assert_equal "Mohamed Salah FPL Prediction GW8 | Fantasy Forecast", player_meta_title(@player, @forecast)
  end

  test "a season forecast is titled for the season" do
    assert_equal "Mohamed Salah FPL Prediction Season | Fantasy Forecast",
                 player_meta_title(@player, @forecast.merge(horizon: "season"))
  end

  test "a player without a forecast still has a title worth searching" do
    assert_equal "Mohamed Salah FPL Stats and Forecast | Fantasy Forecast", player_meta_title(@player, nil)
  end

  test "the description gives his club, price, ownership, points and grade" do
    assert_equal "Mohamed Salah (Liverpool midfielder, £14.5m, 41.2% owned): 6.2 expected points for " \
                 "Gameweek 8, graded B+. Fixtures, form and the FPL alternatives worth comparing.",
                 player_meta_description(@player, @forecast, @stats)
  end

  test "an ungraded forecast says nothing about a grade" do
    description = player_meta_description(@player, @forecast.merge(grade: TierCalculator::UNGRADED), @stats)

    assert_includes description, "expected points for Gameweek 8. Fixtures"
  end

  test "a player with no forecast and no figures is still described" do
    assert_equal "Mohamed Salah (Liverpool midfielder): price, ownership, fixtures and form for your " \
                 "Fantasy Premier League decisions.",
                 player_meta_description(@player, nil, nil)
  end
end
