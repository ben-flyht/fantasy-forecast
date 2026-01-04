require "test_helper"

class BotForecasterTest < ActiveSupport::TestCase
  def setup
    # Clear all data to ensure test isolation
    Forecast.delete_all
    Statistic.delete_all
    Performance.delete_all
    Player.delete_all

    @team = Team.find_or_create_by!(fpl_id: 400) do |t|
      t.name = "Bot Forecaster Test Team"
      t.short_name = "BFT"
    end

    # Create enough players for each position
    @players = {}
    @player_counts = {}
    position_index = 0
    FantasyForecast::POSITION_CONFIG.each do |position, config|
      @players[position] = []
      player_count = config[:slots] + 2
      @player_counts[position] = player_count
      player_count.times do |i|
        player = Player.create!(
          fpl_id: 10000 + (position_index * 100) + i,
          first_name: "Bot",
          last_name: "#{position.capitalize}#{i}",
          position: position,
          team: @team
        )
        @players[position] << player
      end
      position_index += 1
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

    # Create statistics for all players (both total_points and minutes to indicate they played)
    @players.values.flatten.each do |player|
      Statistic.create!(
        player: player,
        gameweek: @finished_gw,
        type: "total_points",
        value: rand(1..15)
      )
      Statistic.create!(
        player: player,
        gameweek: @finished_gw,
        type: "minutes",
        value: rand(60..90)
      )
    end

    @bot_user = create_test_bot
    @strategy_config = {
      performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ]
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

  test "creates forecasts for all players in all positions" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Should create forecasts for ALL players, not just slot count
    expected_total = @player_counts.values.sum
    assert_equal expected_total, forecasts.count
  end

  test "creates forecasts for all players in each position" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    FantasyForecast::POSITION_CONFIG.each_key do |position|
      position_forecasts = forecasts.select { |f| f.player.position == position }
      assert_equal @player_counts[position], position_forecasts.count, "Expected #{@player_counts[position]} #{position} forecasts"
    end
  end

  test "assigns ranks to all forecasts" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    assert forecasts.all? { |f| f.rank.present? }, "All forecasts should have a rank"

    # Check ranks are sequential per position
    FantasyForecast::POSITION_CONFIG.each_key do |position|
      position_forecasts = forecasts.select { |f| f.player.position == position }
      ranks = position_forecasts.map(&:rank).sort
      expected_ranks = (1..@player_counts[position]).to_a
      assert_equal expected_ranks, ranks, "Ranks should be sequential for #{position}"
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
    Forecast.create!(user: @bot_user, player: existing_player, gameweek: @next_gw, rank: 1)

    initial_count = Forecast.where(user: @bot_user, gameweek: @next_gw).count
    assert_equal 1, initial_count

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Should have replaced the single forecast with forecasts for all players
    expected_total = @player_counts.values.sum
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
    other_forecast = Forecast.create!(user: @bot_user, player: other_player, gameweek: other_gw, rank: 1)

    BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Other gameweek forecast should still exist
    assert Forecast.exists?(other_forecast.id)
  end

  test "does not affect forecasts for other users" do
    other_bot = create_test_bot

    # Create forecast for different user
    other_player = @players["defender"].first
    other_forecast = Forecast.create!(user: other_bot, player: other_player, gameweek: @next_gw, rank: 1)

    BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Other user's forecast should still exist
    assert Forecast.exists?(other_forecast.id)
  end

  test "works with empty strategy config (random selection)" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: {}, gameweek: @next_gw)

    expected_total = @player_counts.values.sum
    assert_equal expected_total, forecasts.count
  end

  test "forecasts are persisted to database" do
    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    assert forecasts.all?(&:persisted?)

    db_count = Forecast.where(user: @bot_user, gameweek: @next_gw).count
    assert_equal forecasts.count, db_count
  end

  test "uses position-specific configs when provided" do
    # Create position-specific config with different metrics per position
    position_config = {
      positions: {
        goalkeeper: {
          performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ]
        },
        defender: {
          performance: [ { metric: "total_points", weight: 1.0, lookback: 5, recency: "linear" } ]
        },
        midfielder: {
          performance: [ { metric: "total_points", weight: 1.0, lookback: 1, recency: "exponential" } ]
        },
        forward: {
          performance: [ { metric: "total_points", weight: 1.0, lookback: 2, recency: "none" } ]
        }
      }
    }

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: position_config, gameweek: @next_gw)

    expected_total = @player_counts.values.sum
    assert_equal expected_total, forecasts.count

    # Verify we got forecasts for each position
    FantasyForecast::POSITION_CONFIG.each_key do |position|
      position_forecasts = forecasts.select { |f| f.player.position == position }
      assert_equal @player_counts[position], position_forecasts.count, "Expected #{@player_counts[position]} #{position} forecasts"
    end
  end

  test "falls back to global config when position-specific config not provided" do
    # Config with only some positions defined
    partial_config = {
      performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none" } ],
      positions: {
        goalkeeper: {
          performance: [ { metric: "total_points", weight: 1.0, lookback: 5, recency: "linear" } ]
        }
      }
    }

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: partial_config, gameweek: @next_gw)

    expected_total = @player_counts.values.sum
    assert_equal expected_total, forecasts.count
  end

  # Availability-aware lookback tests
  test "availability-aware lookback includes gameweeks where player was available" do
    # Create additional gameweeks for lookback testing
    gw398 = Gameweek.create!(fpl_id: 398, name: "Gameweek 398", start_time: 4.weeks.ago, is_finished: true)
    gw399 = Gameweek.create!(fpl_id: 399, name: "Gameweek 399", start_time: 3.weeks.ago, is_finished: true)

    player = @players["midfielder"].first

    # Player was available and played in all gameweeks
    [ gw398, gw399, @finished_gw ].each_with_index do |gw, i|
      # Use find_or_create to handle existing statistics from setup
      Statistic.find_or_create_by!(player: player, gameweek: gw, type: "total_points") do |s|
        s.value = 10 + i
      end
      Statistic.find_or_create_by!(player: player, gameweek: gw, type: "minutes") do |s|
        s.value = 90
      end
      Statistic.find_or_create_by!(player: player, gameweek: gw, type: "chance_of_playing") do |s|
        s.value = 100.0
      end
    end

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Player should be ranked based on all 3 available gameweeks
    player_forecast = forecasts.find { |f| f.player_id == player.id }
    assert_not_nil player_forecast
    assert player_forecast.rank.present?
  end

  test "availability-aware lookback skips gameweeks where player was injured" do
    # Create additional gameweeks for lookback testing
    gw398 = Gameweek.create!(fpl_id: 398, name: "Gameweek 398", start_time: 4.weeks.ago, is_finished: true)
    gw399 = Gameweek.create!(fpl_id: 399, name: "Gameweek 399", start_time: 3.weeks.ago, is_finished: true)

    player = @players["midfielder"].first

    # GW398: Player scored 15 points, was available and played
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "total_points") { |s| s.value = 15 }
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "minutes") { |s| s.value = 90 }
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "chance_of_playing") { |s| s.value = 100.0 }

    # GW399: Player was injured (0% chance), didn't play (0 minutes)
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "total_points") { |s| s.value = 0 }
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "minutes") { |s| s.value = 0 }
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "chance_of_playing") { |s| s.value = 0.0 }

    # GW400 (@finished_gw): Player recovered and played
    Statistic.find_by(player: player, gameweek: @finished_gw, type: "total_points")&.update!(value: 12)
    Statistic.find_or_create_by!(player: player, gameweek: @finished_gw, type: "chance_of_playing") { |s| s.value = 100.0 }
    # minutes already created in setup

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Player should be ranked - the injured gameweek (GW399) should be skipped
    player_forecast = forecasts.find { |f| f.player_id == player.id }
    assert_not_nil player_forecast
    assert player_forecast.rank.present?
  end

  test "availability-aware lookback assumes available when no availability data exists" do
    # Create additional gameweeks for lookback testing
    gw398 = Gameweek.create!(fpl_id: 398, name: "Gameweek 398", start_time: 4.weeks.ago, is_finished: true)
    gw399 = Gameweek.create!(fpl_id: 399, name: "Gameweek 399", start_time: 3.weeks.ago, is_finished: true)

    player = @players["midfielder"].first

    # Create performance stats WITH minutes but WITHOUT availability data (backward compatibility)
    [ gw398, gw399, @finished_gw ].each_with_index do |gw, i|
      stat = Statistic.find_by(player: player, gameweek: gw, type: "total_points")
      if stat
        stat.update!(value: 8 + i)
      else
        Statistic.create!(player: player, gameweek: gw, type: "total_points", value: 8 + i)
      end
      Statistic.find_or_create_by!(player: player, gameweek: gw, type: "minutes") do |s|
        s.value = 90
      end
      # Note: NOT creating chance_of_playing statistics - simulating old data
    end

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    # Player should be ranked - all gameweeks should be included (assumed available)
    player_forecast = forecasts.find { |f| f.player_id == player.id }
    assert_not_nil player_forecast
    assert player_forecast.rank.present?
  end

  test "min_availability config option is respected" do
    # Create additional gameweeks for lookback testing
    gw398 = Gameweek.create!(fpl_id: 398, name: "Gameweek 398", start_time: 4.weeks.ago, is_finished: true)
    gw399 = Gameweek.create!(fpl_id: 399, name: "Gameweek 399", start_time: 3.weeks.ago, is_finished: true)

    player = @players["midfielder"].first

    # GW398: Player was fully available (100%) and played
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "total_points") { |s| s.value = 15 }
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "minutes") { |s| s.value = 90 }
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "chance_of_playing") { |s| s.value = 100.0 }

    # GW399: Player had 50% chance but still played
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "total_points") { |s| s.value = 5 }
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "minutes") { |s| s.value = 60 }
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "chance_of_playing") { |s| s.value = 50.0 }

    # GW400: Player was fully available and played
    Statistic.find_by(player: player, gameweek: @finished_gw, type: "total_points")&.update!(value: 10)
    Statistic.find_or_create_by!(player: player, gameweek: @finished_gw, type: "chance_of_playing") { |s| s.value = 100.0 }
    # minutes already created in setup

    # Config with higher min_availability threshold (75%)
    high_threshold_config = {
      performance: [ { metric: "total_points", weight: 1.0, lookback: 3, recency: "none", min_availability: 75 } ]
    }

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: high_threshold_config, gameweek: @next_gw)

    # Player should be ranked, GW399 (50% availability) should be skipped
    player_forecast = forecasts.find { |f| f.player_id == player.id }
    assert_not_nil player_forecast
    assert player_forecast.rank.present?
  end

  test "lookback excludes gameweeks where player team has not played yet" do
    # This tests the scenario where:
    # - Current gameweek (GW400) is in progress
    # - Player A's team played on Saturday (has stats including minutes)
    # - Player B's team plays Sunday (no stats synced yet - no minutes stat at all)
    # - Bot generates forecasts for next gameweek (GW401)
    # - Player B should NOT be penalized for missing GW400 stats

    # Create additional gameweeks
    gw398 = Gameweek.create!(fpl_id: 398, name: "Gameweek 398", start_time: 4.weeks.ago, is_finished: true)
    gw399 = Gameweek.create!(fpl_id: 399, name: "Gameweek 399", start_time: 3.weeks.ago, is_finished: true)

    # Mark @finished_gw (GW400) as current (in progress, not finished)
    @finished_gw.update!(is_finished: false, is_current: true)

    player_played = @players["forward"].first
    player_not_played = @players["forward"].second

    # GW398 & GW399: Both players played and scored well
    [ gw398, gw399 ].each_with_index do |gw, i|
      # Player who played
      Statistic.find_or_create_by!(player: player_played, gameweek: gw, type: "total_points") { |s| s.value = 10 + i }
      Statistic.find_or_create_by!(player: player_played, gameweek: gw, type: "minutes") { |s| s.value = 90 }

      # Player whose team hasn't played yet (but historically performed well)
      Statistic.find_or_create_by!(player: player_not_played, gameweek: gw, type: "total_points") { |s| s.value = 12 + i }
      Statistic.find_or_create_by!(player: player_not_played, gameweek: gw, type: "minutes") { |s| s.value = 90 }
    end

    # GW400 (current, in progress):
    # - player_played's team has played (has minutes stat)
    # - player_not_played's team hasn't played yet (NO minutes stat - match not synced)

    # Player who played in current GW - keep their stats from setup
    Statistic.find_by(player: player_played, gameweek: @finished_gw, type: "total_points")&.update!(value: 8)
    # minutes already exists from setup

    # Player whose team hasn't played - DELETE their minutes stat to simulate match not played
    # (In real sync, a minutes stat is only created after a match is played)
    Statistic.find_by(player: player_not_played, gameweek: @finished_gw, type: "minutes")&.destroy
    Statistic.find_by(player: player_not_played, gameweek: @finished_gw, type: "total_points")&.destroy

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    player_played_forecast = forecasts.find { |f| f.player_id == player_played.id }
    player_not_played_forecast = forecasts.find { |f| f.player_id == player_not_played.id }

    # Both players should be ranked
    assert_not_nil player_played_forecast
    assert_not_nil player_not_played_forecast
    assert player_played_forecast.rank.present?
    assert player_not_played_forecast.rank.present?

    # Player who hasn't played yet should be ranked HIGHER because their historical
    # average (12, 13 = avg 12.5) is better than player_played's (10, 11, 8 = avg 9.67 with GW400 included)
    # GW400 should be excluded from player_not_played's lookback since no minutes stat exists
    assert player_not_played_forecast.rank < player_played_forecast.rank,
      "Player whose team hasn't played should be ranked higher based on historical performance, not penalized for missing stats in current GW"
  end

  test "lookback includes gameweeks where player got zero minutes but match was played" do
    # A player who was on the bench (0 minutes) should still have that gameweek counted
    # because the match was played - they just didn't come on

    gw398 = Gameweek.create!(fpl_id: 398, name: "Gameweek 398", start_time: 4.weeks.ago, is_finished: true)
    gw399 = Gameweek.create!(fpl_id: 399, name: "Gameweek 399", start_time: 3.weeks.ago, is_finished: true)

    player = @players["midfielder"].first

    # GW398: Player played 90 mins and scored 10 points
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "total_points") { |s| s.value = 10 }
    Statistic.find_or_create_by!(player: player, gameweek: gw398, type: "minutes") { |s| s.value = 90 }

    # GW399: Player was on bench (0 mins, 0 points) - but match WAS played
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "total_points") { |s| s.value = 0 }
    Statistic.find_or_create_by!(player: player, gameweek: gw399, type: "minutes") { |s| s.value = 0 }

    # GW400: Player played and scored
    Statistic.find_by(player: player, gameweek: @finished_gw, type: "total_points")&.update!(value: 8)
    # minutes already exists from setup

    forecasts = BotForecaster.call(user: @bot_user, strategy_config: @strategy_config, gameweek: @next_gw)

    player_forecast = forecasts.find { |f| f.player_id == player.id }
    assert_not_nil player_forecast
    assert player_forecast.rank.present?

    # The 0-point gameweek should be INCLUDED in the average (match was played, player just didn't play)
    # Average should be (10 + 0 + 8) / 3 = 6.0, not (10 + 8) / 2 = 9.0
  end
end
