require "test_helper"
require "webmock/minitest"

class Fpl::SyncPlayerHistoriesTest < ActiveSupport::TestCase
  # The season just gone, for a gameweek played in August 2026. Pinned so the
  # tests say which season they mean rather than working it out the way the code
  # does and agreeing with itself.
  LAST_SEASON = "2025/26".freeze
  OLD_SEASON = "2020/21".freeze

  def setup
    WebMock.disable_net_connect!(allow_localhost: true)
    @gameweek = gameweeks(:next_gw)
    @gameweek.update!(start_time: Time.utc(2026, 8, 15), end_time: Time.utc(2026, 8, 17))
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

  # More players than a single batch, so a run can be cut short mid-way.
  def crowd_of_players(count)
    (1..count).map do |i|
      Player.create!(first_name: "Bulk", last_name: "Player#{i}", short_name: "B#{i}",
                     fpl_id: 7000 + i, code: 7000 + i, team: teams(:arsenal), position: "midfielder")
    end
  end

  test "a run cut short keeps what it collected, and the next one carries on" do
    crowd_of_players(30)
    stub_every_player([ { "season_name" => LAST_SEASON, "total_points" => 100, "minutes" => 2000 } ])

    Fpl::SyncPlayerHistories.call(delay: 0, budget: 0) # stops after the first batch
    stored = Statistic.where(gameweek: @gameweek, type: "last_season_points").count
    assert stored.positive?, "what it managed must be saved, not thrown away"
    assert stored < Player.count, "and it must stop rather than run to the end"

    Fpl::SyncPlayerHistories.call(delay: 0)

    assert_equal Player.count, Statistic.where(gameweek: @gameweek, type: "last_season_points").count,
                 "the next run picks up the players the first one did not reach"
  end

  test "a player FPL has no past for is not asked about again" do
    stub_every_player([])

    Fpl::SyncPlayerHistories.call(delay: 0)
    player = players(:midfielder)

    assert_nil Statistic.find_by(player: player, gameweek: @gameweek, type: "last_season_points")
    assert Statistic.exists?(player: player, gameweek: @gameweek, type: Fpl::SyncPlayerHistories::CHECKED),
           "a receipt, so we do not pay for the same empty answer every hour"
  end

  test "stores last season's totals against the upcoming gameweek" do
    stub_every_player([ { "season_name" => LAST_SEASON, "total_points" => 150, "minutes" => 2700 } ])

    Fpl::SyncPlayerHistories.call(delay: 0)

    player = players(:midfielder)
    assert_equal 150.0, Statistic.find_by(player: player, gameweek: @gameweek, type: "last_season_points").value
    assert_equal 2700.0, Statistic.find_by(player: player, gameweek: @gameweek, type: "last_season_minutes").value
  end

  test "takes the most recent season when a player has several" do
    stub_every_player([
      { "season_name" => "2024/25", "total_points" => 90, "minutes" => 1800 },
      { "season_name" => LAST_SEASON, "total_points" => 210, "minutes" => 3200 }
    ])

    Fpl::SyncPlayerHistories.call(delay: 0)

    assert_equal 210.0, Statistic.find_by(player: players(:midfielder), type: "last_season_points").value
  end

  test "skips players already synced so a re-run costs nothing" do
    stub_every_player([ { "season_name" => LAST_SEASON, "total_points" => 150, "minutes" => 2700 } ])
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

  # A promoted club's squad is full of these: the last time FPL saw them was
  # years ago, and read as last season it makes a regular of a man nobody in this
  # division has picked since.
  test "a season that is not last season is not last season's record" do
    stub_every_player([ { "season_name" => OLD_SEASON, "total_points" => 150, "minutes" => 2700 } ])

    Fpl::SyncPlayerHistories.call(delay: 0)
    player = players(:midfielder)

    assert_nil Statistic.find_by(player: player, gameweek: @gameweek, type: "last_season_minutes"),
               "six years ago is not evidence about this season's team sheet"
    assert Statistic.exists?(player: player, gameweek: @gameweek, type: Fpl::SyncPlayerHistories::CHECKED),
           "and we should not ask again every hour to be told the same thing"
  end

  test "an old season already stored is cleared once we know better" do
    player = players(:midfielder)
    Statistic.create!(player: player, gameweek: @gameweek, type: "last_season_minutes", value: 2700)
    stub_every_player([ { "season_name" => OLD_SEASON, "total_points" => 150, "minutes" => 2700 } ])

    Fpl::SyncPlayerHistories.call(delay: 0)

    assert_nil Statistic.find_by(player: player, gameweek: @gameweek, type: "last_season_minutes"),
               "a record this run has rejected must not stay in circulation"
  end

  test "a player we could not reach is asked again rather than recorded as having no past" do
    Player.pluck(:fpl_id).each do |fpl_id|
      stub_request(:get, "https://fantasy.premierleague.com/api/element-summary/#{fpl_id}/").to_return(status: 503)
    end

    Fpl::SyncPlayerHistories.call(delay: 0)

    assert_not Statistic.exists?(gameweek: @gameweek, type: Fpl::SyncPlayerHistories::CHECKED),
               "nobody answered, which is not the same as an answer of none"
  end
end
