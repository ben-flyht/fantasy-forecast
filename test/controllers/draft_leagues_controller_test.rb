require "test_helper"

class DraftLeaguesControllerTest < ActionDispatch::IntegrationTest
  test "connects with a bare entry id" do
    stub_entry_public(334926, 64899)

    post draft_league_path, params: { entry_id: "334926" }

    assert_redirected_to root_path
    assert_equal "334926", cookies[:draft_entry_id]
    assert_equal "64899", cookies[:draft_league_id]
  end

  test "connects by pasting the Points page URL" do
    stub_entry_public(334926, 64899)

    post draft_league_path, params: { entry_id: "https://draft.premierleague.com/entry/334926/event/11" }

    assert_redirected_to root_path
    assert_equal "334926", cookies[:draft_entry_id]
    assert_equal "64899", cookies[:draft_league_id]
  end

  test "rejects input with no recognisable id" do
    post draft_league_path, params: { entry_id: "my team" }

    assert_response :redirect
    assert_nil cookies[:draft_entry_id]
  end

  test "alerts when the entry cannot be resolved to a league" do
    stub_request(:get, "https://draft.premierleague.com/api/entry/999/public").to_return(status: 404, body: "")

    post draft_league_path, params: { entry_id: "999" }

    assert_response :redirect
    assert_nil cookies[:draft_league_id]
  end

  private

  def stub_entry_public(entry_id, league_id)
    stub_request(:get, "https://draft.premierleague.com/api/entry/#{entry_id}/public")
      .to_return(status: 200, body: { "entry" => { "league_set" => [ league_id ] } }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end
end
