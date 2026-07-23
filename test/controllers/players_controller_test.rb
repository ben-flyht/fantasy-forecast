require "test_helper"

class PlayersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @player = players(:goalkeeper)
    @player2 = players(:midfielder)

    # Create test team
    @test_team = Team.create!(name: "Test Team", short_name: "TST", fpl_id: 96)

    # Clear data to avoid conflicts
    Forecast.destroy_all
    Gameweek.destroy_all

    # Create gameweeks for testing
    @gameweek1 = Gameweek.create!(
      fpl_id: 1,
      name: "Gameweek 1",
      start_time: 1.week.ago,
      end_time: Time.current - 1.second,
      is_current: true,
      is_next: false,
      is_finished: false
    )

    @gameweek2 = Gameweek.create!(
      fpl_id: 2,
      name: "Gameweek 2",
      start_time: Time.current,
      end_time: 1.week.from_now - 1.second,
      is_current: false,
      is_next: true,
      is_finished: false
    )

    @gameweek5 = Gameweek.create!(
      fpl_id: 5,
      name: "Gameweek 5",
      start_time: 4.weeks.from_now,
      end_time: 5.weeks.from_now - 1.second,
      is_current: false,
      is_next: false,
      is_finished: false
    )
  end

  test "players index should be accessible" do
    get root_path
    assert_response :success
  end

  test "should show forecasts data when available" do
    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1)
    Forecast.create!(player: @player2, gameweek: @gameweek5, rank: 2)

    get gameweek_position_path(gameweek: 5, position: "#{@player.position}s")
    assert_response :success
    assert_includes response.body, @player.short_name
  end

  test "should filter by gameweek parameter" do
    Forecast.create!(player: @player, gameweek: @gameweek1, rank: 1)
    Forecast.create!(player: @player2, gameweek: @gameweek2, rank: 1)

    get gameweek_position_path(gameweek: 1, position: "forwards")
    assert_response :success

    get gameweek_position_path(gameweek: 2, position: "forwards")
    assert_response :success
  end

  test "should filter by position parameter" do
    midfielder = Player.create!(
      first_name: "Test", last_name: "Midfielder",
      team: @test_team, position: "midfielder", fpl_id: 999
    )

    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1)
    Forecast.create!(player: midfielder, gameweek: @gameweek5, rank: 1)

    get gameweek_position_path(gameweek: 5, position: "forwards")
    assert_response :success

    get gameweek_position_path(gameweek: 5, position: "goalkeepers")
    assert_response :success

    get gameweek_position_path(gameweek: 5, position: "midfielders")
    assert_response :success
  end

  test "should redirect old query-param URLs to clean URLs" do
    get root_path, params: { gameweek: 5, position: "midfielder" }
    assert_response :moved_permanently
    assert_redirected_to gameweek_position_path(gameweek: 5, position: "midfielders")
  end

  test "should default to next gameweek" do
    get root_path
    assert_response :success

    # Should see gameweek 2 (next gameweek) in page title or content
    assert_includes response.body, "Gameweek 2"
  end

  test "should default to latest forecasted gameweek when the season is over" do
    # Season finished: every gameweek done, none current or next
    [ @gameweek1, @gameweek2, @gameweek5 ].each do |gw|
      gw.update!(is_current: false, is_next: false, is_finished: true)
    end

    Forecast.create!(player: @player, gameweek: @gameweek1, rank: 1)
    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1)

    get root_path
    assert_response :success

    # Defaults to the latest gameweek that has forecasts (5), not a hardcoded start
    assert_select "select[name=gameweek] option[selected]", text: "5"
    # Dropdown lists only forecasted weeks: 1 is present, 2 (no forecasts) is absent
    assert_select "select[name=gameweek] option", text: "1"
    assert_select "select[name=gameweek] option", text: "2", count: 0
  end

  test "should handle invalid gameweek gracefully" do
    get gameweek_position_path(gameweek: 10, position: "forwards")
    assert_response :redirect
  end

  test "old /players path should redirect to root" do
    get "/players"
    assert_response :redirect
    assert_redirected_to root_path
  end

  test "should show player page with slugged URL" do
    get player_path(@player)
    assert_response :success
    assert_includes response.body, @player.full_name
  end

  test "should redirect old-style numeric ID to slugged URL" do
    get "/players/#{@player.id}"
    assert_response :moved_permanently
    assert_redirected_to player_path(@player)
  end

  test "should redirect incorrect slug to canonical URL" do
    get "/players/wrong-slug-#{@player.fpl_id}"
    assert_response :moved_permanently
    assert_redirected_to player_path(@player)
  end

  test "should return 404 for non-existent player" do
    get "/players/non-existent-99999"
    assert_response :not_found
  end

  test "available filter shows only free agents when a draft league is connected" do
    available, mine, theirs = create_draft_scenario

    get gameweek_position_path(gameweek: 5, position: "midfielders", availability: "available")

    assert_response :success
    assert_includes response.body, available.short_name
    assert_not_includes response.body, mine.short_name
    assert_not_includes response.body, theirs.short_name
  end

  test "mine filter shows only the connected user's players" do
    available, mine, theirs = create_draft_scenario

    get gameweek_position_path(gameweek: 5, position: "midfielders", availability: "mine")

    assert_response :success
    assert_includes response.body, mine.short_name
    assert_not_includes response.body, available.short_name
    assert_not_includes response.body, theirs.short_name
  end

  test "availability filter is ignored when no league is connected" do
    available, mine, theirs = create_draft_scenario(connect: false)

    get gameweek_position_path(gameweek: 5, position: "midfielders", availability: "available")

    assert_response :success
    [ available, mine, theirs ].each { |p| assert_includes response.body, p.short_name }
  end

  private

  # Builds three forecasted midfielders (a free agent, one owned by the connected
  # user, one owned by a rival), stubs the public Draft API, and connects the
  # league via cookies unless connect: false.
  def create_draft_scenario(connect: true)
    available = Player.create!(first_name: "Free", last_name: "Agent", team: @test_team, position: "midfielder", fpl_id: 900, code: 900)
    mine = Player.create!(first_name: "My", last_name: "Keeper", team: @test_team, position: "midfielder", fpl_id: 901, code: 901)
    theirs = Player.create!(first_name: "Their", last_name: "Rival", team: @test_team, position: "midfielder", fpl_id: 902, code: 902)
    [ available, mine, theirs ].each_with_index { |p, i| Forecast.create!(player: p, gameweek: @gameweek5, rank: i + 1) }

    entry_id = 334926
    league_id = 64899
    stub_draft_request("league/#{league_id}/element-status", "element_status" => [
      { "element" => 1, "owner" => nil, "status" => "a" },
      { "element" => 2, "owner" => entry_id, "status" => "o" },
      { "element" => 3, "owner" => 999, "status" => "o" }
    ])
    stub_draft_request("bootstrap-static", "elements" => [
      { "id" => 1, "code" => 900 }, { "id" => 2, "code" => 901 }, { "id" => 3, "code" => 902 }
    ])
    stub_draft_request("league/#{league_id}/details",
      "league_entries" => [ { "id" => 1, "entry_id" => entry_id, "entry_name" => "My Team" } ],
      "matches" => [])

    if connect
      cookies[:draft_entry_id] = entry_id.to_s
      cookies[:draft_league_id] = league_id.to_s
    end

    [ available, mine, theirs ]
  end

  def stub_draft_request(path, body)
    stub_request(:get, "https://draft.premierleague.com/api/#{path}")
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end
end
