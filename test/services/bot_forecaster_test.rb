require "test_helper"

class BotForecasterTest < ActiveSupport::TestCase
  def setup
    @team = Team.find_or_create_by!(fpl_id: 400) do |t|
      t.name = "Bot Forecaster Test Team"
      t.short_name = "BFT"
    end

    # Create enough players for each position
    @players = {}
    FantasyForecast::POSITION_CONFIG.each do |position, config|
      @players[position] = []
      (config[:slots] + 2).times do |i|
        player = Player.create!(
          fpl_id: 4000 + position.hash.abs % 1000 + i,
          first_name: "Bot",
          last_name: "#{position.capitalize}#{i}",
          position: position,
          team: @team
        )
        @players[position] << player
      end
    end

    # Create gameweeks
    @finished_gw = Gameweek.create!(
      fpl_id: 400,
      name: "Gameweek 400",
      start_time: 2.weeks.ago,
      is_finished: true
    )

    @next_gw = Gameweek.create!(
      fpl_id: 401,
      name: "Gameweek 401",
      start_time: 1.day.from_now,
      is_next: true,
      is_finished: false
    )

    # Create statistics for all players
    Player.all.each do |player|
      Statistic.create!(
        player: player,
        gameweek: @finished_gw,
        type: "total_points",
        value: rand(1..15)
      )
    end

    @bot_user = User.find_or_create_bot("botforecastertest")
    @strategy_config = {
      strategies: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ]
    }
  end

  test "raises error if user is not a bot" do
    human_user = users(:one)

    assert_raises(ArgumentError, "User must be a bot") do
      BotForecaster.call(user: human_user, strategy_config: @strategy_config, gameweek: @next_gw)
    end
  end

  test "raises error if gameweek is nil" do
    assert_raises(ArgumentError, "No gameweek available") do
      BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: nil)
    end
  end

  test "creates forecasts for all positions" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    expected_total = FantasyForecast::POSITION_CONFIG.values.sum { |c| c[:slots] }
    assert_equal expected_total, forecasts.count
  end

  test "creates correct number of forecasts per position" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    FantasyForecast::POSITION_CONFIG.each do |position, config|
      position_forecasts = forecasts.select { |f| f.player.position == position }
      assert_equal config[:slots], position_forecasts.count, "Expected #{config[:slots]} #{position} forecasts"
    end
  end

  test "all forecasts belong to the bot user" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    assert forecasts.all? { |f| f.user == @bot_user }
  end

  test "all forecasts are for the specified gameweek" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    assert forecasts.all? { |f| f.gameweek == @next_gw }
  end

  test "clears existing forecasts before creating new ones" do
    # Create some existing forecasts
    existing_player = @players["midfielder"].first
    Forecast.create!(user: @bot_user, player: existing_player, gameweek: @next_gw)

    initial_count = Forecast.where(user: @bot_user, gameweek: @next_gw).count
    assert_equal 1, initial_count

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Should have replaced the single forecast with the full set
    expected_total = FantasyForecast::POSITION_CONFIG.values.sum { |c| c[:slots] }
    assert_equal expected_total, forecasts.count
    assert_equal expected_total, Forecast.where(user: @bot_user, gameweek: @next_gw).count
  end

  test "does not affect forecasts for other gameweeks" do
    other_gw = Gameweek.create!(
      fpl_id: 402,
      name: "Gameweek 402",
      start_time: 2.weeks.from_now,
      is_finished: false
    )

    # Create forecast for different gameweek
    other_player = @players["forward"].first
    other_forecast = Forecast.create!(user: @bot_user, player: other_player, gameweek: other_gw)

    BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Other gameweek forecast should still exist
    assert Forecast.exists?(other_forecast.id)
  end

  test "does not affect forecasts for other users" do
    other_bot = User.find_or_create_bot("otherbotuser")

    # Create forecast for different user
    other_player = @players["defender"].first
    other_forecast = Forecast.create!(user: other_bot, player: other_player, gameweek: @next_gw)

    BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Other user's forecast should still exist
    assert Forecast.exists?(other_forecast.id)
  end

  test "works with empty strategy config (random selection)" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: {}, gameweek: @next_gw)

    expected_total = FantasyForecast::POSITION_CONFIG.values.sum { |c| c[:slots] }
    assert_equal expected_total, forecasts.count
  end

  test "forecasts are persisted to database" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    assert forecasts.all?(&:persisted?)

    db_count = Forecast.where(user: @bot_user, gameweek: @next_gw).count
    assert_equal forecasts.count, db_count
  end
end
