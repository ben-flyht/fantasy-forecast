require "test_helper"

class ForecasterRankingsTest < ActiveSupport::TestCase
  def setup
    # Create test data
    @user1 = users(:one)
    @user2 = users(:two)

    # Create gameweeks - use high IDs to avoid conflicts
    @gw1 = Gameweek.create!(fpl_id: 106, name: "Gameweek 106", start_time: 6.weeks.ago, is_finished: true)
    @gw2 = Gameweek.create!(fpl_id: 107, name: "Gameweek 107", start_time: 5.weeks.ago, is_finished: true)
    @gw3 = Gameweek.create!(fpl_id: 108, name: "Gameweek 108", start_time: 4.weeks.ago, is_finished: true)

    # Create players - use high IDs to avoid conflicts
    @team = Team.find_or_create_by!(fpl_id: 101) do |t|
      t.name = "Test Team"
      t.short_name = "TST"
    end
    @player1 = Player.find_or_create_by!(fpl_id: 1001) do |p|
      p.first_name = "Test"
      p.last_name = "Player1"
      p.position = :forward
      p.team = @team
    end
    @player2 = Player.find_or_create_by!(fpl_id: 1002) do |p|
      p.first_name = "Test"
      p.last_name = "Player2"
      p.position = :midfielder
      p.team = @team
    end
    @player3 = Player.find_or_create_by!(fpl_id: 1003) do |p|
      p.first_name = "Test"
      p.last_name = "Player3"
      p.position = :defender
      p.team = @team
    end

    # Create performances
    Performance.create!(player: @player1, gameweek: @gw1, gameweek_score: 10, team: @team)
    Performance.create!(player: @player2, gameweek: @gw1, gameweek_score: 8, team: @team)
    Performance.create!(player: @player3, gameweek: @gw1, gameweek_score: 6, team: @team)

    Performance.create!(player: @player1, gameweek: @gw2, gameweek_score: 12, team: @team)
    Performance.create!(player: @player2, gameweek: @gw2, gameweek_score: 9, team: @team)
    Performance.create!(player: @player3, gameweek: @gw2, gameweek_score: 7, team: @team)

    Performance.create!(player: @player1, gameweek: @gw3, gameweek_score: 11, team: @team)
    Performance.create!(player: @player2, gameweek: @gw3, gameweek_score: 10, team: @team)
    Performance.create!(player: @player3, gameweek: @gw3, gameweek_score: 8, team: @team)
  end

  test "accuracy is average of forecast accuracies" do
    # User 1 makes 8 forecasts across 3 gameweeks
    # GW1: 3 forecasts, avg = (0.8 + 0.7 + 0.6) / 3 = 0.7
    Forecast.create!(user: @user1, player: @player1, gameweek: @gw1, accuracy: 0.8)
    Forecast.create!(user: @user1, player: @player2, gameweek: @gw1, accuracy: 0.7)
    Forecast.create!(user: @user1, player: @player3, gameweek: @gw1, accuracy: 0.6)

    # GW2: 3 forecasts, avg = (0.9 + 0.8 + 0.7) / 3 = 0.8
    Forecast.create!(user: @user1, player: @player1, gameweek: @gw2, accuracy: 0.9)
    Forecast.create!(user: @user1, player: @player2, gameweek: @gw2, accuracy: 0.8)
    Forecast.create!(user: @user1, player: @player3, gameweek: @gw2, accuracy: 0.7)

    # GW3: 2 forecasts, avg = (0.85 + 0.75) / 2 = 0.8
    Forecast.create!(user: @user1, player: @player1, gameweek: @gw3, accuracy: 0.85)
    Forecast.create!(user: @user1, player: @player2, gameweek: @gw3, accuracy: 0.75)

    # User 2 makes 6 forecasts across 2 gameweeks with higher accuracy
    # GW2: 3 forecasts, avg = (0.95 + 0.85 + 0.75) / 3 = 0.85
    Forecast.create!(user: @user2, player: @player1, gameweek: @gw2, accuracy: 0.95)
    Forecast.create!(user: @user2, player: @player2, gameweek: @gw2, accuracy: 0.85)
    Forecast.create!(user: @user2, player: @player3, gameweek: @gw2, accuracy: 0.75)

    # GW3: 3 forecasts, avg = (0.9 + 0.8 + 0.7) / 3 = 0.8
    Forecast.create!(user: @user2, player: @player1, gameweek: @gw3, accuracy: 0.9)
    Forecast.create!(user: @user2, player: @player2, gameweek: @gw3, accuracy: 0.8)
    Forecast.create!(user: @user2, player: @player3, gameweek: @gw3, accuracy: 0.7)

    rankings = ForecasterRankings.overall

    user1_ranking = rankings.find { |r| r[:user_id] == @user1.id }
    user2_ranking = rankings.find { |r| r[:user_id] == @user2.id }

    # User 1: avg across gameweeks = (0.7 + 0.8 + 0.8) / 3 = 0.7667
    assert_equal 8, user1_ranking[:forecast_count]
    expected_user1_avg_accuracy = (0.7 + 0.8 + 0.8) / 3
    assert_in_delta expected_user1_avg_accuracy, user1_ranking[:accuracy_score], 0.0001

    # User 2: avg across gameweeks = (0.85 + 0.8) / 2 = 0.825
    assert_equal 6, user2_ranking[:forecast_count]
    expected_user2_avg_accuracy = (0.85 + 0.8) / 2
    assert_in_delta expected_user2_avg_accuracy, user2_ranking[:accuracy_score], 0.0001

    # User 2 should rank higher (better accuracy)
    assert user2_ranking[:accuracy_score] > user1_ranking[:accuracy_score],
      "User 2 with higher accuracy should rank higher"
  end

  test "handles users with no forecasts" do
    rankings = ForecasterRankings.overall

    # If there are no forecasts, rankings should be empty or handle gracefully
    assert_kind_of Array, rankings
  end

  test "gameweek-specific accuracy calculation" do
    # Create forecasts for a single gameweek
    # 2 forecasts, avg = (0.8 + 0.6) / 2 = 0.7
    Forecast.create!(user: @user1, player: @player1, gameweek: @gw1, accuracy: 0.8)
    Forecast.create!(user: @user1, player: @player2, gameweek: @gw1, accuracy: 0.6)

    rankings = ForecasterRankings.for_gameweek(@gw1.fpl_id)

    user1_ranking = rankings.find { |r| r[:user_id] == @user1.id }

    assert_equal 2, user1_ranking[:forecast_count]
    expected_avg_accuracy = 0.7
    assert_in_delta expected_avg_accuracy, user1_ranking[:accuracy_score], 0.0001
  end
end
