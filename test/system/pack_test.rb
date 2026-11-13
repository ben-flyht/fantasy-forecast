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

  def saved?(picks)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until Selection.last.reload.picks == picks
      true
    end
  rescue Timeout::Error
    false
  end

  test "the whole pack is dealt, every pair is picked by tapping, and a pick can be changed" do
    sign_in
    assert_selector "[data-pack-sealed]"
    click_on "Open pack"
    assert_selector "[data-pack-pair]", count: 5
    assert_no_selector "[data-pack-sealed]", visible: :visible
    assert_text "0 of 5 picked"

    5.times do |index|
      all("[data-pack-pair]")[index].all(".pack-card--choice").first.click
      assert_text(index == 4 ? "That's your five" : "#{index + 1} of 5 picked")
    end
    assert_selector "[data-pack-choice=kept]", count: 5

    assert saved?("aaaaa"), "every pick reaches the server"
    last_card = find("#pack_pair_4 .pack-choice:last-child .pack-card")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", last_card)
    scrolled = page.evaluate_script("window.scrollY")
    last_card.click
    assert_selector "#pack_pair_4 .pack-choice:last-child[data-pack-choice=kept]"
    assert saved?("aaaab"), "the pick reaches the server"
    assert_equal scrolled, page.evaluate_script("window.scrollY"), "picking leaves the page where it was"

    first("[data-pack-pair]").all(".pack-card--choice").last.click
    assert_selector "[data-pack-pair]:first-child .pack-choice--passed:first-child"
    assert_selector "[data-pack-pair]:first-child [data-pack-choice=kept]:last-child"
    assert saved?("baaab"), "the changed pick reaches the server"
  end

  test "clicking anywhere on a leaderboard row opens that player's team, and Close puts it away" do
    sign_in
    assert_selector "[data-pack-sealed]"
    Selection.last.update!(picks: "aaaaa")
    @gameweek.update!(start_time: 1.hour.ago, is_next: false, is_current: true)

    visit pack_current_leaderboard_path
    find("[data-pack-row]", text: "Sys T").find("span", text: "Sys T", match: :first).click
    within("dialog[open]") do
      assert_selector "[data-pack-row-pair]", count: 5
      click_on "Close"
    end
    assert_no_selector "dialog[open]"
  end
end
