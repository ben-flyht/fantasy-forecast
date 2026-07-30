require "test_helper"
require "webmock/minitest"

class Fpl::SyncPlayerHistoriesTest < ActiveSupport::TestCase
  def setup
    WebMock.disable_net_connect!(allow_localhost: true)
    @gameweek = gameweeks(:next_gw)
  end

  def teardown
    WebMock.allow_net_connect!
  end

  def stub_summary(fpl_id, past_seasons)
    stub_request(:get, "https://fantasy.premierleague.com/api/element-summary/#{fpl_id}/")
      .to_return(status: 200, body: { "history_past" => past_seasons }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_every_player(past_seasons)
    Player.pluck(:fpl_id).each { |fpl_id| stub_summary(fpl_id, past_seasons) }
  end

  test "stores last season's totals against the upcoming gameweek" do
    stub_every_player([ { "season_name" => "2024/25", "total_points" => 150, "minutes" => 2700 } ])

    Fpl::SyncPlayerHistories.call(delay: 0)

    player = players(:midfielder)
    assert_equal 150.0, Statistic.find_by(player: player, gameweek: @gameweek, type: "last_season_points").value
    assert_equal 2700.0, Statistic.find_by(player: player, gameweek: @gameweek, type: "last_season_minutes").value
  end

  test "takes the most recent season when a player has several" do
    stub_every_player([
      { "season_name" => "2023/24", "total_points" => 90, "minutes" => 1800 },
      { "season_name" => "2024/25", "total_points" => 210, "minutes" => 3200 }
    ])

    Fpl::SyncPlayerHistories.call(delay: 0)

    assert_equal 210.0, Statistic.find_by(player: players(:midfielder), type: "last_season_points").value
  end

  test "skips players already synced so a re-run costs nothing" do
    stub_every_player([ { "season_name" => "2024/25", "total_points" => 150, "minutes" => 2700 } ])
    Fpl::SyncPlayerHistories.call(delay: 0)
    WebMock.reset!

    # No stubs registered, so any further request would raise.
    assert Fpl::SyncPlayerHistories.call(delay: 0)
  end

  test "a player with no past seasons is stored as nothing rather than zero" do
    stub_every_player([])

    Fpl::SyncPlayerHistories.call(delay: 0)

    assert_nil Statistic.find_by(player: players(:midfielder), type: "last_season_points")
  end
end
