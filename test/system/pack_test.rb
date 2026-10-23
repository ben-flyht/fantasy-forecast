require "application_system_test_case"

class PackTest < ApplicationSystemTestCase
  setup do
    PackEntry.destroy_all
    WeeklyPack.destroy_all
    Manager.destroy_all
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
        Forecast.create!(player: player, gameweek: @gameweek, horizon: "gameweek", rank: i + 1, score: 6.0 - (i * 0.4))
        Statistic.create!(player: player, gameweek: @gameweek, type: "now_cost", value: 45 + i)
      end
    end
  end

  test "a pack is opened, picked, benched and scored by clicking cards" do
    visit pack_path(seed: 5)
    find("[data-pack-target=sealed]").click

    7.times do |pair|
      assert_text(/Pair #{pair + 1} of 7/i)
      pick_first_card
    end

    2.times do |place|
      assert_text(/Bench #{place + 1} of 2/i)
      pick_first_card
    end

    assert_selector "[data-pack-stage=scored]"
    assert_selector "[data-pack-pair]", count: 7
  end

  test "a manager follows the emailed link, opens the weekly pack, locks it in and finds the leaderboard" do
    manager = Manager.create!(email: "sys@example.com", nickname: "Systematic")

    visit pack_sign_in_path(token: manager.generate_token_for(:pack_link))
    find("[data-pack-target=sealed]").click

    7.times do |pair|
      assert_text(/Pair #{pair + 1} of 7/i)
      pick_first_card
    end
    2.times do |place|
      assert_text(/Bench #{place + 1} of 2/i)
      pick_first_card
    end

    click_button "Lock in my team"
    assert_text "Locked in. Good luck."

    click_link "Leaderboard"
    assert_text "Systematic (you)"
    assert_text "The forecast"
  end

  def pick_first_card
    assert_selector ".pack-stage.is-settled"
    first("[data-pack-choice] [role=button]").click
  end
end
