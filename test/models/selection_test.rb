require "test_helper"

class SelectionTest < ActiveSupport::TestCase
  setup do
    [ Selection, User, Statistic, Forecast, Player, Gameweek, Team ].each(&:destroy_all)
    @gameweek = Gameweek.create!(fpl_id: 8, name: "Gameweek 8", start_time: 3.days.from_now, is_next: true)
    team = Team.create!(fpl_id: 993, code: 993, name: "Week City", short_name: "WKC")
    { "goalkeeper" => 6, "defender" => 12, "midfielder" => 12, "forward" => 8 }.each_with_index do |(position, count), group|
      count.times do |i|
        id = 6600 + (group * 100) + i
        player = Player.create!(first_name: "P", last_name: "#{position}#{i}", fpl_id: id, code: id, team: team, position: position)
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.3), working: { "minutes" => 90 })
      end
    end
    @ana = User.create!(email: " Ana@Example.com ", first_name: " Ana ", last_name: "Lopes")
    @bo = User.create!(email: "bo@example.com", first_name: "Bo", last_name: "Kim")
  end

  def offered(selection) = selection.pack.pairs.map { |pair| pair.cards.map(&:player_id) }

  test "a user is one email, shown on the leaderboard by first name and last initial" do
    assert_equal "ana@example.com", @ana.email
    assert_equal "Ana L.", @ana.leaderboard_name
  end

  test "each user is dealt their own random pack, and keeps it" do
    ana = Selection.deal(@ana, @gameweek)
    bo = Selection.deal(@bo, @gameweek)

    assert_equal ana, Selection.deal(@ana, @gameweek)
    assert_not_equal offered(ana), offered(bo)
    Forecast.update_all("score = 7.0 - score")
    assert_equal offered(ana), offered(Selection.find(ana.id))
  end

  test "a selection records what was offered and a pick per pair, in any order, changeable" do
    selection = Selection.deal(@ana, @gameweek)

    assert selection.choose(2, "b")
    assert_equal "xxbxx", selection.reload.picks
    assert_not selection.complete?

    assert selection.choose(2, "a")
    [ 0, 1, 3, 4 ].each { |pair| selection.choose(pair, "b") }
    assert selection.complete?
    assert_equal "bbabb", selection.reload.picks

    assert_not selection.choose(5, "a")
    assert_not selection.choose(nil, "a")
    assert_not selection.choose(0, "x")
    assert_equal 5, selection.offered.size
    assert_equal %w[expected_points fixtures player_id rank], selection.offered.first["cards"].first.keys.sort
  end

  test "one selection per user per gameweek" do
    Selection.deal(@ana, @gameweek)

    assert_not Selection.new(user: @ana, gameweek: @gameweek, offered: []).valid?
  end

  test "a gameweek's packs only open once the one before it is finished" do
    previous = Gameweek.create!(fpl_id: 7, name: "Gameweek 7", start_time: 4.days.ago, is_current: true)

    assert_nil Selection.deal(@ana, @gameweek)

    previous.update!(is_finished: true)
    assert Selection.deal(@ana, @gameweek)
  end

  test "no pack is dealt once the deadline has passed, and picks stop" do
    selection = Selection.deal(@ana, @gameweek)
    selection.choose(0, "a")
    @gameweek.update!(start_time: 1.second.ago)

    assert_nil Selection.deal(@bo, @gameweek)
    assert_not selection.reload.choose(0, "b")
    assert_not selection.reload.choose(1, "a")
    assert_equal "axxxx", selection.reload.pack_hand.code
  end
end
