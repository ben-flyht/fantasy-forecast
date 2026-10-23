require "test_helper"

class PacksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    PackEntry.destroy_all
    WeeklyPack.destroy_all
    Manager.destroy_all
    Performance.destroy_all
    Statistic.destroy_all
    Forecast.destroy_all
    Player.destroy_all
    Gameweek.destroy_all
    Team.destroy_all

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
        Statistic.create!(player: player, gameweek: @gameweek, type: "now_cost", value: 45 + i)
      end
    end
  end

  def finished_code(seed)
    pack = PackDraw.call(gameweek: @gameweek, seed: seed)
    PackScore.new(pack).forecast.code
  end

  test "a new pack is a random seed with an address of its own" do
    get new_pack_path

    assert_redirected_to %r{/pack/\d+\z}
  end

  test "an unopened pack shows its first pair" do
    get pack_path(seed: 3)

    assert_response :success
    assert_select "[data-pack-stage=picking]"
    assert_select "h2", /Pair 1 of 5/
    assert_select "meta[name=robots][content*=noindex]"
  end

  test "a finished pack says how many of the forecast's picks you shared" do
    get pack_path(seed: 3, hand: finished_code(3))

    assert_response :success
    assert_select "[data-pack-stage=scored]"
    assert_select "[data-pack-verdict]", /5 of 5/
    assert_select "[data-pack-verdict]", /same five as the forecast/
    assert_select "[data-pack-pair]", count: 5
  end

  test "going against the forecast on every pair is said plainly, pair by pair" do
    pack = PackDraw.call(gameweek: @gameweek, seed: 3)
    keeps = pack.pairs.map { |pair| pair.cards.index(pair.cards.min_by(&:expected_points)) }

    get pack_path(seed: 3, hand: PackHand.new(pack, keeps: keeps).code)

    assert_select "[data-pack-verdict]", /0 of 5/
    css_select("[data-pack-pair]").each do |row|
      mine, theirs = row.css("td").map { |cell| cell.text.squish }
      assert_not_equal mine, theirs
    end
  end

  test "a hand longer than the pack is not a pack page" do
    get "/pack/3/aaaaaa"

    assert_response :not_found
  end

  test "with nothing forecast there is no pack to open" do
    Forecast.destroy_all

    get pack_path(seed: 3)

    assert_response :success
    assert_select "h2", /No pack to open/
  end

  def sign_in
    @manager = Manager.create!(email: "ana@example.com")
    get pack_sign_in_path(token: @manager.generate_token_for(:pack_link))
  end

  def weekly_code
    PackScore.new(WeeklyPack.for(@gameweek).pack).forecast.code
  end

  test "Play is in the navigation, and the real pack asks for an email first" do
    get root_path
    assert_select "a[href=?]", pack_landing_path, text: "Play"

    get pack_landing_path
    assert_select "h1", /Beat the Algorithm/
    assert_select "input[type=email][name=email]"
    assert_select "li", /One pack a week, one go/
  end

  test "asking for a pack emails a link that signs you in" do
    assert_enqueued_emails(1) { post pack_sign_ins_path, params: { email: "New@Example.com" } }
    assert_select "[data-pack-sent]", /new@example.com/

    get pack_sign_in_path(token: Manager.find_by(email: "new@example.com").generate_token_for(:pack_link))
    follow_redirect!
    assert_redirected_to weekly_pack_path(gameweek: 1)
  end

  test "a bad email is sent back to the form" do
    assert_no_enqueued_emails { post pack_sign_ins_path, params: { email: "nope" } }

    assert_response :unprocessable_entity
    assert_select "input[type=email]"
  end

  test "picking the weekly pack needs you signed in" do
    get weekly_pack_path(gameweek: 1)

    assert_redirected_to pack_landing_path
  end

  test "signed in, this week's pack is the same pack every time" do
    sign_in
    get weekly_pack_path(gameweek: 1)
    first = css_select(".pack-card__name").map(&:text)

    get weekly_pack_path(gameweek: 1)
    assert_equal first, css_select(".pack-card__name").map(&:text)
    assert_select "h1", /Beat the Algorithm: Gameweek 1/
    assert_select "h2", /Pair 1 of 5/
  end

  test "you lock in one pack a week, and then that is the pack you see" do
    sign_in
    code = weekly_code

    get weekly_pack_path(gameweek: 1, hand: code)
    assert_select "[data-pack-lock]", /One pack a week, one go/

    assert_difference(-> { PackEntry.count }, 1) { post weekly_pack_entry_path(gameweek: 1), params: { hand: code } }
    assert_no_difference(-> { PackEntry.count }) { post weekly_pack_entry_path(gameweek: 1), params: { hand: code.tr("ab", "ba") } }

    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-locked]", /your one pack for Gameweek 1/
    assert_select "[data-pack-lock]", count: 0
  end

  test "a half-picked pack cannot be locked in" do
    sign_in
    weekly_code

    assert_no_difference(-> { PackEntry.count }) { post weekly_pack_entry_path(gameweek: 1), params: { hand: "aa" } }
  end

  test "after the deadline the pack is closed to anyone who has not locked in" do
    sign_in
    code = weekly_code
    @gameweek.update!(start_time: 1.minute.ago)

    get weekly_pack_path(gameweek: 1)
    assert_select "h2", /has closed/
    assert_no_difference(-> { PackEntry.count }) { post weekly_pack_entry_path(gameweek: 1), params: { hand: code } }
  end

  test "once the games start, a locked-in pack shows its score live against the algorithm's" do
    sign_in
    code = weekly_code
    post weekly_pack_entry_path(gameweek: 1), params: { hand: code }
    WeeklyPack.last.pack.pairs.flat_map(&:cards).each do |card|
      Performance.create!(player: card.player, gameweek: @gameweek, team: card.player.team, gameweek_score: 3)
    end
    @gameweek.update!(start_time: 1.hour.ago, is_next: false, is_current: true)

    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-verdict]", /live/
    assert_select "[data-pack-verdict]", /18\s+v 18/

    @gameweek.update!(is_finished: true)
    get weekly_pack_path(gameweek: 1)
    assert_select "[data-pack-verdict]", /final/
    assert_select "[data-pack-verdict]", /Level with the algorithm/
  end

  test "a finished pack's link can be shared and opened by anyone" do
    code = weekly_code

    get weekly_pack_path(gameweek: 1, hand: code)

    assert_select "[data-pack-stage=scored]"
    assert_select "[aria-label='Share my pack']"
    assert_select "[data-pack-lock]", count: 0
  end

  test "practice packs need no email, and you pick up where you left off" do
    get practice_pack_path
    follow_redirect!
    seed = request.path[%r{/pack/(\d+)}, 1]

    get pack_path(seed: seed, hand: "ab")
    get practice_pack_path
    assert_redirected_to pack_path(seed: seed, hand: "ab")
    follow_redirect!
    assert_match "where you left off", flash[:notice]
    assert_select "[data-pack-resume] a[href=?]", new_pack_path

    get new_pack_path
    assert_redirected_to %r{/pack/\d+\z}
  end
end
