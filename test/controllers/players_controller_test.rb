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
    get rankings_path
    assert_response :success
  end

  test "says when the forecast on the page was worked out" do
    forecast = Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1, score: 4.2)
    forecast.update_column(:updated_at, 3.hours.ago)

    get gameweek_position_path(gameweek: 5, position: "#{@player.position}s")

    assert_select "time", text: "about 3 hours ago"
  end

  test "should show forecasts data when available" do
    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1, score: 4.2)
    Forecast.create!(player: @player2, gameweek: @gameweek5, rank: 2, score: 3.1)

    get gameweek_position_path(gameweek: 5, position: "#{@player.position}s")
    assert_response :success
    assert_includes response.body, @player.display_name
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

  test "a player page offers the arguments he is part of" do
    rival = Player.create!(first_name: "Test", last_name: "Keeper", team: @test_team,
                           position: @player.position, fpl_id: 998)
    Forecast.create!(player: @player, gameweek: @gameweek2, rank: 1, score: 4.2)
    Forecast.create!(player: rival, gameweek: @gameweek2, rank: 2, score: 4.0)

    get player_path(@player)

    assert_select "a[href=?]", comparison_path(pair: Matchup.new(@player, rival).slug)
  end

  test "a ranking page has a share card of its own" do
    Forecast.create!(player: @player, gameweek: @gameweek5, rank: 1, score: 4.2)

    get gameweek_position_path(gameweek: 5, position: "#{@player.position}s", format: :png)

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal [ ShareCard::WIDTH, ShareCard::HEIGHT ], png_size(response.body)
  end

  test "a player has a share card of his own" do
    Forecast.create!(player: @player, gameweek: @gameweek2, rank: 1, score: 4.2)

    get player_path(@player, format: :png)

    assert_response :success
    assert_equal [ ShareCard::WIDTH, ShareCard::HEIGHT ], png_size(response.body)
  end

  test "a player with no forecast still has a card" do
    get player_path(@player2, format: :png)

    assert_response :success
    assert_equal [ ShareCard::WIDTH, ShareCard::HEIGHT ], png_size(response.body)
  end

  test "an old address for a card is sent to the card, not the page" do
    get "/players/wrong-slug-#{@player.fpl_id}.png"

    assert_redirected_to player_path(@player, format: :png)
  end

  test "a ranking page tells a preview where to find its card" do
    get season_position_path(position: "midfielders")

    assert_select "meta[property='og:image'][content=?]",
                  "#{ApplicationHelper::BASE_URL}/season/midfielders.png"
    assert_select "meta[property='og:image:width'][content=?]", ShareCard::WIDTH.to_s
  end

  test "a player page tells a preview where to find its card" do
    get player_path(@player)

    assert_select "meta[property='og:image'][content=?]",
                  "#{ApplicationHelper::BASE_URL}#{player_path(@player)}.png"
  end

  test "the rankings page is its own canonical, not the coming gameweek's" do
    get rankings_path

    assert_select "link[rel=canonical][href=?]", "#{ApplicationHelper::BASE_URL}/rankings"
  end

  test "a filtered ranking still answers to the rankings page" do
    get rankings_path, params: { team_id: @test_team.id }

    assert_select "link[rel=canonical][href=?]", "#{ApplicationHelper::BASE_URL}/rankings"
  end

  test "a ranking page is its own canonical" do
    get season_position_path(position: "midfielders")

    assert_select "link[rel=canonical][href=?]", "#{ApplicationHelper::BASE_URL}/season/midfielders"
  end

  test "should redirect old query-param URLs to clean URLs" do
    get rankings_path, params: { gameweek: 5, position: "midfielder" }
    assert_response :moved_permanently
    assert_redirected_to gameweek_position_path(gameweek: 5, position: "midfielders")
  end

  test "should default to next gameweek" do
    get rankings_path
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

    get rankings_path
    assert_response :success

    # Still defaults to the latest gameweek that has forecasts (5) for display
    assert_includes response.body, "Gameweek 5"
    # The toggle offers the three distances a forecast is read at, never a list of
    # every week played. Matched on the accessible name: each option carries a short
    # name and a full one, and the visible text is whichever the breakpoint picks.
    assert_select "[aria-label='Forecast horizon'] a[aria-label='Rest of Season']"
    assert_select "[aria-label='Forecast horizon'] a[aria-label='Gameweek 1']", count: 0
    assert_select "[aria-label='Forecast horizon'] a", count: 3
  end

  test "the season route shows season forecasts" do
    Forecast.create!(player: @player, gameweek: @gameweek2, rank: 1, score: 40.0, horizon: "season")

    get season_position_path(position: "#{@player.position}s")
    assert_response :success
    assert_includes response.body, @player.display_name
    assert_includes response.body, "Rest of Season"
    assert_select "[aria-label='Forecast horizon'] a[aria-current=page][aria-label='Rest of Season']"
  end

  test "the season page the horizon dropdown asks for is the season page" do
    get rankings_path(gameweek: "season", position: "#{@player.position}s")

    assert_redirected_to season_position_path(position: "#{@player.position}s")
  end

  test "the season used to be spelled as a gameweek, and that link still works" do
    get "/gameweeks/ros/#{@player.position}s"

    assert_response :moved_permanently
    assert_redirected_to season_position_path(position: "#{@player.position}s")
  end

  test "a team filter survives the trip to the season page" do
    get rankings_path(gameweek: "season", position: "#{@player.position}s", team_id: @test_team.id)

    assert_redirected_to season_position_path(position: "#{@player.position}s", team_id: @test_team.id)
  end

  # Named by the week rather than by "next": the title beside it already says which
  # gameweek this is, and "next" only means something if you know where you are.
  test "the horizon toggle names the gameweek and the season, as links" do
    get rankings_path

    assert_select "[aria-label='Forecast horizon'] a[aria-label='Gameweek 2']"
    assert_select "[aria-label='Forecast horizon'] a[aria-label='Next 5 Gameweeks']"
    assert_select "[aria-label='Forecast horizon'] a[aria-label='Rest of Season']"
    assert_select "[aria-label='Forecast horizon'] a[aria-current=page][aria-label='Gameweek 2']"
  end

  # The positions are the same control as the horizon, and links for the same
  # reason: those four pages are ones people arrive on from a search.
  test "the positions are links, and keep the team you filtered by" do
    get gameweek_position_path(gameweek: @gameweek2.fpl_id, position: "#{@player.position}s",
                               team_id: @test_team.id)

    assert_select "[aria-label=Position] a", count: 4
    assert_select "[aria-label=Position] a[href=?]",
                  gameweek_position_path(gameweek: @gameweek2.fpl_id, position: "goalkeepers",
                                         team_id: @test_team.id)
  end

  # A keeper's prices and a forward's are different ranges, so carrying a price
  # across a change of position would hide half the list.
  test "a price filter does not survive a change of position" do
    get gameweek_position_path(gameweek: @gameweek2.fpl_id, position: "#{@player.position}s",
                               max_price: "6.0")

    assert_select "[aria-label=Position] a[href*=?]", "max_price", count: 0
  end

  test "the positions follow the horizon you are reading at" do
    get season_position_path(position: "#{@player.position}s")

    assert_select "[aria-label=Position] a[href=?]", season_position_path(position: "goalkeepers")
  end

  # A link inside a turbo frame swaps the frame without touching the address bar
  # unless the frame is told to advance it.
  test "choosing a horizon changes the address, not just the table" do
    get rankings_path

    assert_select "turbo-frame#rankings_container[data-turbo-action=advance]"
  end

  # The filters submit the horizon along with everything else. Without it the form
  # asks for /gameweeks/null/goalkeepers the moment you change team or position.
  test "changing a filter keeps the horizon you are reading at" do
    get rankings_path

    assert_select "#filters-form input[type=hidden][name=gameweek][value=?]", @gameweek2.fpl_id.to_s
  end

  test "the season horizon travels with the filters too" do
    get season_position_path(position: "#{@player.position}s")

    assert_select "#filters-form input[type=hidden][name=gameweek][value=season]"
  end

  # A crawler follows links, not form posts, so both horizons are addresses.
  test "the horizon toggle sends you to the season page, filters and all" do
    get rankings_path(position: "#{@player.position}s", team_id: @test_team.id)

    assert_select "[aria-label='Forecast horizon'] a[href=?]",
                  season_position_path(position: "#{@player.position}s", team_id: @test_team.id)
  end

  test "a weekly forecast is not shown under the season horizon" do
    Forecast.create!(player: @player, gameweek: @gameweek2, rank: 1, score: 4.0, horizon: "gameweek")

    get season_position_path(position: "#{@player.position}s")
    assert_response :success
    assert_not_includes response.body, @player.display_name
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

  test "a price band keeps only players who cost within it" do
    budget = Player.create!(first_name: "Budget", last_name: "Cheapman", short_name: "B.Cheapman",
                            team: @test_team, position: "forward", fpl_id: 501)
    premium = Player.create!(first_name: "Premium", last_name: "Dearman", short_name: "P.Dearman",
                             team: @test_team, position: "forward", fpl_id: 502)

    Forecast.create!(player: budget, gameweek: @gameweek5, rank: 1, score: 5.0)
    Forecast.create!(player: premium, gameweek: @gameweek5, rank: 2, score: 4.0)
    Statistic.create!(player: budget, gameweek: @gameweek5, type: "now_cost", value: 50)
    Statistic.create!(player: premium, gameweek: @gameweek5, type: "now_cost", value: 90)

    get gameweek_position_path(gameweek: 5, position: "forwards", min_price: "6.0", max_price: "10.0")

    assert_response :success
    assert_includes response.body, premium.display_name
    assert_not_includes response.body, budget.display_name
  end

  test "a price band survives the trip to the clean URL" do
    get rankings_path(gameweek: 5, position: "forward", min_price: "6.0", max_price: "10.0")

    assert_redirected_to gameweek_position_path(gameweek: 5, position: "forwards",
                                                min_price: "6.0", max_price: "10.0")
  end

  test "rank reflects the whole field, not the price-filtered subset" do
    cheap = Player.create!(first_name: "Cheap", last_name: "One", short_name: "C.One",
                           team: @test_team, position: "forward", fpl_id: 511)
    mid = Player.create!(first_name: "Mid", last_name: "Two", short_name: "M.Two",
                         team: @test_team, position: "forward", fpl_id: 512)
    dear = Player.create!(first_name: "Dear", last_name: "Three", short_name: "D.Three",
                          team: @test_team, position: "forward", fpl_id: 513)

    Forecast.create!(player: cheap, gameweek: @gameweek5, rank: 1, score: 6.0)
    Forecast.create!(player: mid, gameweek: @gameweek5, rank: 2, score: 5.0)
    Forecast.create!(player: dear, gameweek: @gameweek5, rank: 3, score: 4.0)
    Statistic.create!(player: cheap, gameweek: @gameweek5, type: "now_cost", value: 45)
    Statistic.create!(player: mid, gameweek: @gameweek5, type: "now_cost", value: 70)
    Statistic.create!(player: dear, gameweek: @gameweek5, type: "now_cost", value: 95)

    get gameweek_position_path(gameweek: 5, position: "forwards", min_price: "9.0", max_price: "10.0")

    assert_response :success
    assert_includes response.body, dear.display_name
    assert_not_includes response.body, cheap.display_name
    assert_equal "3", response.body[/tabular-nums text-zinc-900">(\d+)</, 1]
  end

  test "rank reflects the whole field when filtering by team" do
    other_team = Team.create!(name: "Other", short_name: "OTH", fpl_id: 97)
    top = Player.create!(first_name: "Top", last_name: "Scorer", short_name: "T.Scorer",
                         team: other_team, position: "forward", fpl_id: 521)
    second = Player.create!(first_name: "Second", last_name: "Best", short_name: "S.Best",
                            team: @test_team, position: "forward", fpl_id: 522)

    Forecast.create!(player: top, gameweek: @gameweek5, rank: 1, score: 6.0)
    Forecast.create!(player: second, gameweek: @gameweek5, rank: 2, score: 5.0)

    get gameweek_position_path(gameweek: 5, position: "forwards", team_id: @test_team.id)

    assert_response :success
    assert_includes response.body, second.display_name
    assert_not_includes response.body, top.display_name
    assert_equal "2", response.body[/tabular-nums text-zinc-900">(\d+)</, 1]
  end

  # A page that leans on a dozen readings must not fall over when a player has
  # none of them. All three cases below exist in the real data.
  test "a player with no forecast still renders his page" do
    stranger = Player.create!(first_name: "No", last_name: "Forecast", short_name: "N.Forecast",
                              team: @test_team, position: "defender", fpl_id: 611)

    get player_path(stranger)

    assert_response :success
    assert_includes response.body, "No Forecast"
  end

  test "a player with no club renders without competing for a start" do
    loner = Player.create!(first_name: "No", last_name: "Club", short_name: "N.Club",
                           position: "defender", fpl_id: 612)

    get player_path(loner)

    assert_response :success
    assert_not_includes response.body, "Competing for a start"
  end

  test "a player we hold no price for is offered no alternatives" do
    priceless = Player.create!(first_name: "No", last_name: "Price", short_name: "N.Price",
                               team: @test_team, position: "defender", fpl_id: 613)
    Forecast.create!(player: priceless, gameweek: @gameweek2, rank: 1, score: 4.0)

    get player_path(priceless)

    assert_response :success
    assert_not_includes response.body, "affordable"
    assert_not_includes response.body, "Better for the money"
  end

  # FPL publishes its own expected points, which is the one figure a reader can
  # mark ours against for free. It belongs to a single week, so the season view
  # must not quote it.
  test "FPL's own estimate is compared for a week and left out of a season" do
    rated = Player.create!(first_name: "Rated", last_name: "Player", short_name: "R.Player",
                           team: @test_team, position: "defender", fpl_id: 614)
    Forecast.create!(player: rated, gameweek: @gameweek2, rank: 1, score: 6.0, horizon: "gameweek")
    Forecast.create!(player: rated, gameweek: @gameweek2, rank: 1, score: 90.0, horizon: "season")
    Statistic.create!(player: rated, gameweek: @gameweek2, type: "ep_next", value: 4.0)

    get player_path(rated)
    assert_includes response.body, "FPL&#39;s own estimate of 4.0"

    get player_path(rated, horizon: "season")
    assert_not_includes response.body, "FPL&#39;s own estimate"
  end
end
