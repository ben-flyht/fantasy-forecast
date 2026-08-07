require "application_system_test_case"

# Sharing is JavaScript, so a controller test can only say the button is on the page.
# What it cannot say is what the button hands over, and that is the whole point: the
# card exists for whoever pastes the link, and the link has to be the page's canonical
# rather than whatever filters happened to be on.
class SharingTest < ApplicationSystemTestCase
  setup do
    Squad.destroy_all
    @gameweek = gameweeks(:next_gw)
    Squad.create!(gameweek: @gameweek, horizon: "gameweek", formation: "4-4-2",
                  cost: 985, expected_points: 60,
                  picks: [ { "player_id" => players(:midfielder).id, "position" => "midfielder",
                             "team_id" => players(:midfielder).team_id, "cost" => 55,
                             "expected_points" => 5.1, "starting" => true } ])
  end

  # navigator.share only exists on a phone, so it is replaced here to record what it
  # was handed. Without this the test would be exercising the clipboard fallback and
  # saying nothing about the path almost everybody takes.
  def record_share_sheet
    page.execute_script(<<~JS)
      window.shared = null
      navigator.share = (data) => { window.shared = data; return Promise.resolve() }
    JS
  end

  test "sharing a page offers its canonical address, not the one in the bar" do
    visit rankings_path(team_id: teams(:arsenal).id)
    record_share_sheet

    find("button[data-controller=share]").click

    assert_equal "#{ApplicationHelper::BASE_URL}/rankings",
                 page.evaluate_script("window.shared && window.shared.url")
  end

  test "the squad shares the squad, titled so a share sheet has something to say" do
    visit squad_path
    record_share_sheet

    find("button[data-controller=share]").click

    assert_equal "#{ApplicationHelper::BASE_URL}/squad", page.evaluate_script("window.shared.url")
    assert_predicate page.evaluate_script("window.shared.title").to_s, :present?
  end

  # Every page that draws itself a picture says so. Until there was a button the card
  # only existed for whoever happened to paste a link.
  test "each page with a card of its own has something to press" do
    [ rankings_path, squad_path, player_path(players(:midfielder)) ].each do |path|
      visit path

      assert_selector "button[data-controller=share]", count: 1, wait: 2
    end
  end
end
