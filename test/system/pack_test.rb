require "application_system_test_case"

class PackTest < ApplicationSystemTestCase
  setup do
    Selection.destroy_all
    User.destroy_all
    Statistic.destroy_all
    Forecast.destroy_all
    Player.destroy_all
    Gameweek.destroy_all
    Team.destroy_all

    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 3.days.from_now, is_next: true)
    team = Team.create!(fpl_id: 980, code: 980, name: "Pack Town", short_name: "PKT")
    id = 0
    { "goalkeeper" => 4, "defender" => 10, "midfielder" => 10, "forward" => 6 }.each do |position, count|
      count.times do |i|
        id += 1
        player = Player.create!(first_name: "P", last_name: "#{position}#{i}", short_name: "#{position[0, 3]}#{i}",
                                fpl_id: 7800 + id, code: 7800 + id, team: team, position: position)
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.4), working: { "minutes" => 90 })
        Statistic.create!(player: player, gameweek: @gameweek, type: "now_cost", value: 45 + i)
      end
    end
  end

  def sign_in
    user = User.create!(email: "sys@example.com", first_name: "Sys", last_name: "Tem")
    visit pack_sign_in_path(token: user.generate_token_for(:pack_link))
  end

  test "the whole pack is dealt, every pair is picked by tapping, and a pick can be changed" do
    sign_in
    assert_selector "[data-pack-pair]", count: 5
    assert_text "0 of 5 picked"

    all("[data-pack-pair]").each_with_index do |pair, index|
      pair.all(".pack-card--choice").first.click
      assert_text(index == 4 ? "That's your five" : "#{index + 1} of 5 picked")
    end
    assert_selector "[data-pack-choice=kept]", count: 5

    first("[data-pack-pair]").all(".pack-card--choice").last.click
    assert_selector "[data-pack-pair]:first-child [data-pack-choice=kept]:last-child"
    assert_equal "baaaa", Selection.last.reload.picks
  end
end
