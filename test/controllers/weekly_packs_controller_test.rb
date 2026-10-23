require "test_helper"

class WeeklyPacksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    [ PackEntry, WeeklyPack, Manager, Performance, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    stub_player_images
    @gameweek = Gameweek.create!(fpl_id: 8, name: "Gameweek 8", start_time: 3.days.from_now, is_next: true)
    build_pack_pool(@gameweek)
    @manager = Manager.create!(email: "ana@example.com", nickname: "Ana")
  end

  def sign_in(manager = @manager)
    get pack_sign_in_path(token: manager.generate_token_for(:pack_link))
  end

  def finished_code
    weekly = WeeklyPack.for(@gameweek)
    PackScore.new(weekly.pack).forecast.code
  end

  test "the landing page asks for an email and offers a practice pack" do
    get pack_landing_path

    assert_response :success
    assert_select "input[type=email][name=email]"
    assert_select "input[name=nickname]"
    assert_select "a[href=?]", new_pack_path
  end

  test "asking for a pack emails a link and says so" do
    assert_enqueued_emails 1 do
      post pack_sign_ins_path, params: { email: "New@Example.com", nickname: "Newbie" }
    end

    assert_response :success
    assert_select "[data-pack-sent]", /new@example.com/
    assert_equal "Newbie", Manager.find_by(email: "new@example.com").nickname
  end

  test "somebody else asking with your email cannot rename you" do
    post pack_sign_ins_path, params: { email: "ana@example.com", nickname: "Not Ana" }

    assert_equal "Ana", @manager.reload.nickname
  end

  test "a bad email is sent back to the form" do
    assert_no_enqueued_emails do
      post pack_sign_ins_path, params: { email: "nope", nickname: "Nope" }
    end

    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "the link signs you in and opens this week's pack" do
    sign_in

    assert_redirected_to weekly_pack_path(gameweek: 8)
    follow_redirect!
    assert_select "[data-pack-target=sealed]"
    assert_select "h1", /Gameweek 8 Pack/
  end

  test "an expired link asks for a new one" do
    token = @manager.generate_token_for(:pack_link)
    travel 8.days do
      get pack_sign_in_path(token: token)
    end

    assert_redirected_to pack_landing_path
  end

  test "the weekly pack needs you signed in" do
    get weekly_pack_path(gameweek: 8)

    assert_redirected_to pack_landing_path
  end

  test "a finished pack offers to lock it in, and locking it in enters you once" do
    sign_in
    code = finished_code

    get weekly_pack_path(gameweek: 8, hand: code)
    assert_select "[data-pack-lock] button", /Lock in/

    assert_difference -> { PackEntry.count }, 1 do
      post weekly_pack_entry_path(gameweek: 8), params: { hand: code }
    end
    assert_no_difference -> { PackEntry.count } do
      post weekly_pack_entry_path(gameweek: 8), params: { hand: code }
    end

    get weekly_pack_path(gameweek: 8, hand: "a")
    assert_select "[data-pack-stage=scored]"
    assert_select "[data-pack-lock]", count: 0
  end

  test "a half-picked pack cannot be locked in" do
    sign_in
    WeeklyPack.for(@gameweek)

    assert_no_difference -> { PackEntry.count } do
      post weekly_pack_entry_path(gameweek: 8), params: { hand: "aaa" }
    end
  end

  test "after the deadline the pack is closed to newcomers" do
    sign_in
    WeeklyPack.for(@gameweek)
    @gameweek.update!(start_time: 1.minute.ago)

    get weekly_pack_path(gameweek: 8)
    assert_select "h2", /has closed/

    assert_no_difference -> { PackEntry.count } do
      post weekly_pack_entry_path(gameweek: 8), params: { hand: finished_code }
    end
  end

  test "once the games start your team shows its real points against the forecast" do
    sign_in
    code = finished_code
    post weekly_pack_entry_path(gameweek: 8), params: { hand: code }
    @gameweek.update!(start_time: 1.hour.ago, is_next: false, is_current: true)

    get weekly_pack_path(gameweek: 8)

    assert_select "[data-pack-real]", /live/
  end

  test "the leaderboard ranks everyone in the pack, with the forecast among them" do
    sign_in
    post weekly_pack_entry_path(gameweek: 8), params: { hand: finished_code }
    other = Manager.create!(email: "bo@example.com", nickname: "Bo")
    weekly = WeeklyPack.for(@gameweek)
    worst = PackHand.new(weekly.pack, keeps: weekly.pack.pairs.map { |pair| pair.cards.index(pair.cards.min_by(&:expected_points)) })
    worst = worst.benching(worst.kept.each_index.find { |i| worst.benchable?(i) })
    worst = worst.benching(worst.kept.each_index.find { |i| worst.benchable?(i) })
    weekly.pack_entries.create!(manager: other, hand: worst.code, expected_points: PackScore.new(weekly.pack).points(worst))

    get pack_leaderboard_path(gameweek: 8)

    names = css_select("[data-pack-row]").map { |row| row.text.squish }
    assert_equal 3, names.size
    assert_match "Ana (you)", names.first + names.second
    assert_match "Bo", names.last
    assert(names.any? { |name| name.include?("The forecast") })
  end

  test "my packs lists the packs you have locked in" do
    sign_in
    post weekly_pack_entry_path(gameweek: 8), params: { hand: finished_code }

    get my_packs_path

    assert_select "[data-pack-history]", count: 1
    assert_select "[data-pack-history]", /GW8/
  end
end
