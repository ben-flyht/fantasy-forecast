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
    code.each_char { |choice| post weekly_pack_picks_path(gameweek: 1), params: { keep: choice } }
  end

  def score_everyone(points)
    Player.find_each do |player|
      Performance.create!(player: player, gameweek: @gameweek, team: player.team, gameweek_score: points)
    end
  end

  test "Play is hidden from the public until someone has been sent to /pack" do
    get root_path
    assert_select "a[href=?]", pack_landing_path, count: 0

    get pack_landing_path
    get root_path
    assert_select "a[href=?]", pack_landing_path, text: "Play"
  end

  test "the weekly pack asks who you are first" do
    get pack_landing_path
    assert_select "h1", /Pack of the Week/
    assert_select "input[type=email][name=email]"
    assert_select "input[name=first_name]"
    assert_select "input[name=last_name]"
    assert_select "li", /One pack a week, one go/
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

  test "picking the weekly pack needs you signed in, practice does not" do
    get weekly_pack_path(gameweek: 1)
    assert_redirected_to pack_landing_path

    get pack_path(seed: 3)
    assert_select "h2", /Pair 1 of 5/
    assert_select "nav a, [role=tablist] a, a", text: "Practice"
  end

  test "every user gets their own pack, and every pick is final as they make it" do
    ana = sign_in
    get weekly_pack_path(gameweek: 1)
    assert_select "h2", /Pair 1 of 5/
    assert_select "[data-pack-rules]", /Every pick is final/

    post weekly_pack_picks_path(gameweek: 1), params: { keep: "a" }
    assert_redirected_to weekly_pack_path(gameweek: 1)
    follow_redirect!
    assert_select "h2", /Pair 2 of 5/
    assert_select "a.pack-card--choice[data-turbo-method=post][href=?]", weekly_pack_picks_path(gameweek: 1, keep: "b")
    assert_equal "a", ana.selections.last.picks

    delete pack_sign_out_path
    bo = sign_in(email: "bo@example.com", first_name: "Bo", last_name: "Kim")
    get weekly_pack_path(gameweek: 1)
    assert_not_equal ana.selections.last.offered, bo.selections.last.offered
  end

  test "once five are picked, that is your one pack for the week" do
    user = sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("abaab")

    assert_no_difference(-> { user.selections.last.picks.size }) { post weekly_pack_picks_path(gameweek: 1), params: { keep: "a" } }
    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-locked]", /your one pack for Gameweek 1/
    assert_select "[aria-label='Share my pack']"
    assert_equal "abaab", user.selections.last.picks
  end

  test "after the deadline the pack is closed to anyone who has not started it" do
    sign_in
    @gameweek.update!(start_time: 1.minute.ago)

    get weekly_pack_path(gameweek: 1)
    assert_select "h2", /has closed/
    assert_no_difference(-> { Selection.count }) { post weekly_pack_picks_path(gameweek: 1), params: { keep: "a" } }
  end

  test "a pack left half-picked at the deadline counts the rest as forfeited" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("ab")
    @gameweek.update!(start_time: 1.minute.ago)

    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-stage=scored] [data-pack-forfeit]", count: 3
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
    Selection.deal(bo, @gameweek).then { |selection| "aaxxx".each_char { |choice| selection.pick(choice) } }

    get pack_leaderboard_path(gameweek: 1)
    assert_select "p", /ranked once the games start/
    assert_select "[data-pack-row]", count: 2

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

  test "a finished pack can be shared by its own address and opened by anyone, read-only" do
    user = sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("abaab")
    selection = user.selections.last
    delete pack_sign_out_path

    get pack_selection_path(selection)
    assert_select "[data-pack-stage=scored]"
    assert_select "h2", /Their five/
    assert_select ".pack-card--choice", count: 0
    assert_select "[data-pack-locked]", count: 0
  end

  test "a half-picked pack cannot be shared" do
    user = sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("ab")

    get pack_selection_path(user.selections.last)
    assert_response :not_found
  end

  test "practice never counts, and points you to the real pack" do
    get pack_path(seed: 3, hand: "aaaaa")

    assert_select "[data-pack-practice-done]", /Pack of the Week/
    assert_select "[data-pack-verdict]", count: 0
  end

  test "practice packs need no email, and you pick up where you left off" do
    get practice_pack_path
    follow_redirect!
    seed = request.path[%r{/pack/(\d+)}, 1]

    get pack_path(seed: seed, hand: "ab")
    get practice_pack_path
    assert_redirected_to pack_path(seed: seed, hand: "ab")
    follow_redirect!
    assert_select "a[href=?]", new_pack_path, text: "Start a new practice pack"

    get new_pack_path
    assert_redirected_to %r{/pack/\d+\z}
  end

  test "each pair runs on a ten-second clock that forfeits it" do
    get pack_path(seed: 3, hand: "ab")

    assert_select "[data-controller=pack-pick][data-pack-pick-forfeit-value=?]", pack_path(seed: 3, hand: "abx")
    assert_select "[data-pack-pick-target=clock]", "10"
  end

  test "a forfeited pair shows as time's up and scores nothing" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    pick_all("axaaa")

    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-stage=scored] [data-pack-forfeit]", text: /Time's up/
    assert_select "[data-pack-stage=scored] .pack-card", count: 4
  end

  test "a hand longer than the pack is not a pack page" do
    get "/pack/3/aaaaaa"

    assert_response :not_found
  end
end
