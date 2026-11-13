require "test_helper"

class PacksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    [ Selection, User, Performance, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    stub_player_images

    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 3.days.from_now, is_next: true)
    team = Team.create!(fpl_id: 960, code: 960, name: "Pack City", short_name: "PKC")
    id = 0
    { "goalkeeper" => 4, "defender" => 10, "midfielder" => 10, "forward" => 6 }.each do |position, count|
      count.times do |i|
        id += 1
        player = Player.create!(first_name: "P", last_name: "#{position}#{i}", short_name: "#{position[0, 3]}#{i}",
                                fpl_id: 7500 + id, code: 7500 + id, team: team, position: position)
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.4), working: { "minutes" => 90 })
      end
    end
  end

  def sign_in(email: "ana@example.com", first_name: "Ana", last_name: "Lopes")
    user = User.create!(email: email, first_name: first_name, last_name: last_name)
    get pack_sign_in_path(token: user.generate_token_for(:pack_link))
    user
  end

  def pick_all(code)
    code.each_char.with_index do |choice, pair|
      post weekly_pack_picks_path(gameweek: 1), params: { pair: pair, keep: choice } unless choice == PackHand::FORFEIT
    end
  end

  def choose_all(selection, code)
    code.each_char.with_index { |choice, pair| selection.choose(pair, choice) unless choice == PackHand::FORFEIT }
  end

  def score_everyone(points)
    Player.find_each do |player|
      Performance.create!(player: player, gameweek: @gameweek, team: player.team, gameweek_score: points)
    end
  end

  test "Play is in the header for everyone" do
    get root_path
    assert_select "a[href=?]", pack_landing_path, text: "Play"
  end

  test "every Play page carries the same three tabs: your pack, the weekly board and the season" do
    sign_in
    [ weekly_pack_path(gameweek: 1), pack_current_leaderboard_path, pack_season_leaderboard_path ].zip(%w[Your\ pack Weekly Season]).each do |path, current|
      get path
      assert_select "a[href=?]", pack_landing_path, text: "Your pack"
      assert_select "a", text: "Weekly"
      assert_select "a[href=?]", pack_season_leaderboard_path, text: "Season"
      assert_select "a[aria-current=page]", text: current
    end
  end

  test "the weekly pack asks who you are first" do
    get pack_landing_path
    assert_select "h1", /Pack of the Week/
    assert_select "input[type=email][name=email]"
    assert_select "input[name=first_name]"
    assert_select "input[name=last_name]"
    assert_select "li", /change your mind as often as you like until the FPL deadline/
  end

  test "joining with an email and a name sends a link that signs you in" do
    assert_enqueued_emails(1) { post pack_sign_ins_path, params: { email: "New@Example.com", first_name: "Sam", last_name: "Kerr" } }
    assert_select "[data-pack-sent]", /new@example.com/
    user = User.find_by(email: "new@example.com")
    assert_equal "Sam K.", user.leaderboard_name

    get pack_sign_in_path(token: user.generate_token_for(:pack_link))
    follow_redirect!
    assert_redirected_to weekly_pack_path(gameweek: 1)
  end

  test "a returning email needs no name, and nobody else can rename it" do
    User.create!(email: "ana@example.com", first_name: "Ana", last_name: "Lopes")

    assert_enqueued_emails(1) { post pack_sign_ins_path, params: { email: "ana@example.com", first_name: "Not", last_name: "Ana" } }
    assert_equal "Ana", User.find_by(email: "ana@example.com").first_name
  end

  test "a new email without a name is sent back to the form" do
    assert_no_enqueued_emails { post pack_sign_ins_path, params: { email: "fresh@example.com" } }

    assert_response :unprocessable_entity
    assert_select "input[name=first_name]"
  end

  test "picking the weekly pack needs you signed in" do
    get weekly_pack_path(gameweek: 1)
    assert_redirected_to pack_landing_path
  end

  test "every user gets their own whole pack at once, and can change any pick" do
    ana = sign_in
    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-pair]", count: 5
    assert_select ".pack-card--choice", count: 10
    assert_select "[data-pack-status]", /0 of 5 picked/
    assert_select "a.pack-card--choice[data-turbo-method=post][href=?]", weekly_pack_picks_path(gameweek: 1, pair: 2, keep: "b")

    post weekly_pack_picks_path(gameweek: 1), params: { pair: 0, keep: "a" }
    assert_redirected_to weekly_pack_path(gameweek: 1)
    assert_response :see_other
    follow_redirect!
    assert_select "[data-pack-status]", /1 of 5 picked/
    assert_select "[data-pack-choice=kept]", count: 1
    assert_select "[data-pack-choice=passed]", count: 1
    assert_equal "axxxx", ana.selections.last.picks

    post weekly_pack_picks_path(gameweek: 1), params: { pair: 0, keep: "b" }
    assert_equal "bxxxx", ana.selections.last.picks

    delete pack_sign_out_path
    bo = sign_in(email: "bo@example.com", first_name: "Bo", last_name: "Kim")
    get weekly_pack_path(gameweek: 1)
    assert_not_equal ana.selections.last.offered, bo.selections.last.offered
  end

  test "a full five can still be changed until the deadline, and not a second after" do
    user = sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("abaab")

    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-status]", /That's your five/
    assert_select "[aria-label*=Share]", count: 0

    post weekly_pack_picks_path(gameweek: 1), params: { pair: 1, keep: "a" }
    assert_equal "aaaab", user.selections.last.picks

    @gameweek.update!(start_time: 1.second.ago)
    post weekly_pack_picks_path(gameweek: 1), params: { pair: 1, keep: "b" }
    assert_equal "aaaab", user.selections.last.picks

    follow_redirect!
    assert_select "[data-pack-stage=scored]"
    assert_select ".pack-card--choice", count: 0
  end

  test "a pick naming no pair, or a pair that is not there, changes nothing" do
    user = sign_in
    get weekly_pack_path(gameweek: 1)

    [ { keep: "a" }, { pair: 5, keep: "a" }, { pair: "one", keep: "a" }, { pair: 0, keep: "x" } ].each do |params|
      post weekly_pack_picks_path(gameweek: 1), params: params
    end
    assert_equal "", user.selections.last.picks
  end

  test "after the deadline the pack is closed to anyone who has not started it" do
    sign_in
    @gameweek.update!(start_time: 1.minute.ago)

    get weekly_pack_path(gameweek: 1)
    assert_select "h2", /has closed/
    assert_no_difference(-> { Selection.count }) { post weekly_pack_picks_path(gameweek: 1), params: { pair: 0, keep: "a" } }
  end

  test "a pair left unpicked at the deadline is shown as no pick and scores nothing" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("ab")
    @gameweek.update!(start_time: 1.minute.ago)

    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-stage=scored] [data-pack-forfeit]", text: /No pick/, count: 3
    assert_select "[data-pack-stage=scored] .pack-card", count: 2
  end

  test "next week's pack does not open until every game this gameweek has been played" do
    later = Gameweek.create!(fpl_id: 2, name: "Gameweek 2", start_time: 10.days.from_now)
    sign_in

    get weekly_pack_path(gameweek: 2)
    assert_select "[data-pack-not-open]", /opens once every Gameweek 1 game has been played/
    assert_nil Selection.find_by(gameweek: later)

    @gameweek.update!(is_finished: true, start_time: 1.day.ago)
    Forecast.where(gameweek: @gameweek).find_each { |forecast| forecast.dup.update!(gameweek: later) }
    get weekly_pack_path(gameweek: 2)
    assert_select "h2", /Pair 1 of 5/
  end

  test "while a gameweek is being played, Play shows that gameweek" do
    sign_in
    @gameweek.update!(start_time: 1.hour.ago, is_next: false, is_current: true)
    Gameweek.create!(fpl_id: 2, name: "Gameweek 2", start_time: 7.days.from_now, is_next: true)

    get pack_landing_path

    assert_redirected_to weekly_pack_path(gameweek: 1)
  end

  test "the leaderboard ranks everyone on real points, live then final" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("aaaaa")
    bo = User.create!(email: "bo@example.com", first_name: "Bo", last_name: "Kim")
    choose_all(Selection.deal(bo, @gameweek), "aaxxx")

    score_everyone(3)
    @gameweek.update!(start_time: 1.hour.ago, is_next: false, is_current: true)

    get pack_leaderboard_path(gameweek: 1)
    rows = css_select("[data-pack-row]").map { |row| row.text.squish }
    assert_match(/1st Ana L\. \(you\).*1[58]/, rows.first)
    assert_match(/2nd Bo K\..*[69]/, rows.second)
    assert_select "p", /live points/

    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-verdict]", /1st of 2/
    assert_select "[data-pack-verdict]", /live/
  end

  test "each row has a points column and an accuracy column: how often the better card of a pair was kept" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("aaaaa")
    bo = User.create!(email: "bo@example.com", first_name: "Bo", last_name: "Kim")
    choose_all(Selection.deal(bo, @gameweek), "aaxxx")
    score_everyone(3)
    @gameweek.update!(start_time: 1.hour.ago, is_next: false, is_current: true)

    get pack_leaderboard_path(gameweek: 1)
    assert_select "[data-pack-columns]", /Points.*Accuracy/
    assert_equal %w[100% 40%], css_select("[data-pack-row] [data-pack-accuracy]").map { |cell| cell.text.strip }
  end

  test "the gameweek leaderboard index shows last week's board until this week's deadline passes" do
    @gameweek.update!(start_time: 2.days.ago, is_next: false, is_current: true, is_finished: true)
    second = Gameweek.create!(fpl_id: 2, name: "Gameweek 2", start_time: 3.days.from_now, is_next: true)

    get pack_current_leaderboard_path
    assert_select "h1", /Gameweek 1/
    assert_select "a[href=?]", pack_landing_path, text: "Your pack"
    assert_select "a[href=?][aria-current]", pack_current_leaderboard_path, text: "Weekly"
    assert_select "a[href=?]", pack_season_leaderboard_path, text: "Season"

    get pack_leaderboard_path(gameweek: 2)
    assert_redirected_to pack_current_leaderboard_path

    second.update!(start_time: 1.second.ago)
    get pack_current_leaderboard_path
    assert_select "h1", /Gameweek 2/
  end

  test "a gameweek leaderboard steps back and forward through the started gameweeks someone played" do
    @gameweek.update!(start_time: 16.days.ago, is_next: false, is_finished: true)
    Gameweek.create!(fpl_id: 2, name: "Gameweek 2", start_time: 9.days.ago, is_finished: true)
    third = Gameweek.create!(fpl_id: 3, name: "Gameweek 3", start_time: 2.days.ago, is_current: true)
    Gameweek.create!(fpl_id: 4, name: "Gameweek 4", start_time: 5.days.from_now, is_next: true)
    ana = User.create!(email: "ana@example.com", first_name: "Ana", last_name: "Lopes")
    offered = PackDraw.call(gameweek: @gameweek, seed: 3).dump
    [ @gameweek, third ].each { |gameweek| Selection.new(user: ana, gameweek: gameweek, offered: offered, picks: "aaaaa").save!(validate: false) }

    get pack_leaderboard_path(gameweek: 1)
    assert_select "[data-pack-steps] a", count: 1
    assert_select "[data-pack-steps] a[href=?]", pack_leaderboard_path(gameweek: 3), text: /Gameweek 3/
    assert_select "a[href=?]", pack_leaderboard_path(gameweek: 1), text: "Weekly"

    get pack_current_leaderboard_path
    assert_select "[data-pack-steps] a", count: 1
    assert_select "[data-pack-steps] a[href=?]", pack_leaderboard_path(gameweek: 1), text: /Gameweek 1/
  end

  test "the season leaderboard ranks on each player's best single gameweek" do
    @gameweek.update!(start_time: 9.days.ago, is_next: false, is_finished: true)
    second = Gameweek.create!(fpl_id: 2, name: "Gameweek 2", start_time: 2.days.ago, is_current: true)
    ana = User.create!(email: "ana@example.com", first_name: "Ana", last_name: "Lopes")
    bo = User.create!(email: "bo@example.com", first_name: "Bo", last_name: "Kim")
    offered = PackDraw.call(gameweek: @gameweek, seed: 3).dump
    [ [ ana, @gameweek, "aaaaa" ], [ ana, second, "aaaaa" ], [ bo, @gameweek, "xxxxx" ] ].each do |user, gameweek, picks|
      Selection.new(user: user, gameweek: gameweek, offered: offered, picks: picks).save!(validate: false)
    end
    { @gameweek => 2, second => 5 }.each do |gameweek, points|
      Player.find_each { |player| Performance.create!(player: player, gameweek: gameweek, team: player.team, gameweek_score: points) }
    end

    get pack_season_leaderboard_path
    rows = css_select("[data-pack-season-row]").map { |row| row.text.squish }
    assert_match(/1st Ana L\. 2 weeks played (25|30) 100%/, rows.first)
    assert_match(/2nd Bo K\. 1 week played 0 0%/, rows.second)
    assert_select "a[aria-current]", text: "Season"
    assert_select "[data-pack-season-row] button[data-pack-points]", count: 2
    assert_match(/Best week, Gameweek 2/, css_select("[data-pack-season-row]").first["data-pack-row-summary"])
  end

  test "once the games start, the leaderboard shows each five above the cards they let go, with points on every card" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("abxaa")

    get pack_leaderboard_path(gameweek: 1)
    assert_select "[data-pack-row-hand]", count: 0
    assert_select "button[data-pack-points]", count: 0

    score_everyone(3)
    @gameweek.update!(start_time: 1.hour.ago, is_next: false, is_current: true)

    get pack_leaderboard_path(gameweek: 1)
    assert_select "[data-pack-row] button[data-pack-points][aria-haspopup=dialog]", count: 1
    assert_select "[data-pack-row] template[data-pack-row-hand-template]"
    assert_select "[data-pack-row-hand] [data-pack-row-kept] .pack-card", count: 4
    assert_select "[data-pack-row-hand] [data-pack-row-kept] [data-pack-forfeit]", count: 1
    assert_select "[data-pack-row-hand] [data-pack-row-discarded] .pack-card", count: 4
    assert_select "[data-pack-row-discarded] [data-pack-card-points]", text: "3 pts", count: 4
    assert_select "[data-pack-row-kept] [data-pack-card-points]", text: /\A\s*(3|6) pts\s*\z/, count: 4
    assert_select "[data-pack-row-verdict=level]", text: /Right call/, count: 4
    assert_select "[data-pack-row-verdict=no_pick]", count: 1
  end

  test "a pack is dealt out the first time it is opened, and stays put once picking starts" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    assert_select ".pack-deal"

    pick_all("a")
    get weekly_pack_path(gameweek: 1)
    assert_select ".pack-deal", count: 0
  end

  test "the game lives at /play, and old /pack links still land there" do
    assert_equal "/play", pack_landing_path

    get "/pack"
    assert_redirected_to "/play"

    assert_equal "/play/leaderboard/gameweeks/1", pack_leaderboard_path(gameweek: 1)
    assert_equal "/play/leaderboard/gameweeks", pack_current_leaderboard_path
    assert_equal "/play/leaderboard/seasons", pack_season_leaderboard_path

    get "/pack/gw1"
    assert_redirected_to "/play/gameweeks/1"

    get "/pack/gw1/leaderboard"
    assert_redirected_to "/play/leaderboard/gameweeks/1"

    get "/pack/sign-in/abc--def.ghi"
    assert_redirected_to "/play/sign-in/abc--def.ghi"
  end
end
