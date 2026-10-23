require "test_helper"

class PacksControllerTest < ActionDispatch::IntegrationTest
  setup do
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
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.4))
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

  test "a finished pack is scored against the best it allowed and the forecast's own picks" do
    get pack_path(seed: 3, hand: finished_code(3))

    assert_response :success
    assert_select "[data-pack-stage=scored]"
    assert_select "[data-pack-share]", /100%/
    assert_select "[data-pack-pair]", count: 5
  end

  test "where you and the forecast kept different neighbours, each is shown on his own points" do
    Forecast.find_each { |forecast| forecast.update!(score: 6.0 - (forecast.rank * 0.03)) }
    pack = PackDraw.call(gameweek: @gameweek, seed: 3)
    keeps = pack.pairs.map { |pair| pair.cards.index(pair.cards.min_by(&:expected_points)) }

    get pack_path(seed: 3, hand: PackHand.new(pack, keeps: keeps).code)

    css_select("[data-pack-pair]").each do |row|
      mine, theirs = row.css("td").map { |cell| cell.text.split.last }
      assert_not_equal mine, theirs, row.text.squish
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
end
