require "test_helper"

class Fpl::SyncPayloadsTest < ActiveSupport::TestCase
  setup do
    Gameweek.destroy_all
    @gameweek = Gameweek.create!(fpl_id: 1, name: "Gameweek 1", start_time: 1.day.from_now,
                                 is_next: true, is_current: false, is_finished: false)
  end

  def bootstrap(elements: [ element(1) ], teams: [ { "id" => 1, "name" => "Arsenal" } ],
                events: [ { "id" => 1, "name" => "Gameweek 1" } ])
    { "elements" => elements, "teams" => teams, "events" => events }
  end

  def element(id, **overrides)
    { "id" => id, "web_name" => "Player #{id}", "status" => "a", "news" => "",
      "ep_next" => "4.0", "chance_of_playing_next_round" => nil, "scout_risks" => [] }.merge(overrides)
  end

  def stub_fpl(bootstrap_body, fixtures_body = [ { "id" => 10, "team_h" => 1, "team_a" => 2 } ])
    stub_request(:get, "https://fantasy.premierleague.com/api/bootstrap-static/")
      .to_return(status: 200, body: bootstrap_body.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://fantasy.premierleague.com/api/fixtures/")
      .to_return(status: 200, body: fixtures_body.to_json, headers: { "Content-Type" => "application/json" })
  end

  test "stores every kind FPL publishes" do
    stub_fpl(bootstrap)

    Fpl::SyncPayloads.call

    assert_equal 1, Payload.elements.count
    assert_equal 1, Payload.teams.count
    assert_equal 1, Payload.events.count
    assert_equal 1, Payload.fixtures.count
  end

  test "keeps text, nulls and empty arrays that a numeric column could not hold" do
    stub_fpl(bootstrap(elements: [ element(1, "news" => "Groin injury - Expected back 21 Aug") ]))

    Fpl::SyncPayloads.call
    data = Payload.elements.first.data

    assert_equal "Groin injury - Expected back 21 Aug", data["news"]
    assert_nil data["chance_of_playing_next_round"], "a missing reading stays missing rather than becoming nought"
    assert_equal [], data["scout_risks"]
  end

  test "a second run updates in place rather than piling up rows" do
    stub_fpl(bootstrap)
    Fpl::SyncPayloads.call

    stub_fpl(bootstrap(elements: [ element(1, "status" => "i", "news" => "Knee injury") ]))
    Fpl::SyncPayloads.call

    assert_equal 1, Payload.elements.count, "same player, same gameweek, one row"
    assert_equal "i", Payload.elements.first.data["status"], "and it holds the newer state"
  end

  test "a player FPL stops publishing is removed from the current gameweek" do
    stub_fpl(bootstrap(elements: [ element(1), element(2) ]))
    Fpl::SyncPayloads.call
    assert_equal 2, Payload.elements.count

    stub_fpl(bootstrap(elements: [ element(1) ])) # element 2 has left the league
    Fpl::SyncPayloads.call

    assert_equal [ 1 ], Payload.elements.pluck(:fpl_id)
  end

  test "an earlier gameweek's record is left alone" do
    finished = Gameweek.create!(fpl_id: 0, name: "Gameweek 0", start_time: 2.weeks.ago, is_finished: true)
    Payload.create!(kind: Payload::ELEMENT, fpl_id: 99, gameweek: finished, data: { "web_name" => "Departed" })
    stub_fpl(bootstrap)

    Fpl::SyncPayloads.call

    assert Payload.exists?(fpl_id: 99, gameweek: finished), "history is not rewritten by today's payload"
  end

  test "one field can be read across a whole gameweek without loading the payloads" do
    stub_fpl(bootstrap(elements: [ element(1, "status" => "a"), element(2, "status" => "i") ]))

    Fpl::SyncPayloads.call

    assert_equal({ 1 => "a", 2 => "i" }, Payload.elements.for_gameweek(@gameweek).values_of("status"))
  end

  test "a failed fetch changes nothing" do
    stub_request(:get, "https://fantasy.premierleague.com/api/bootstrap-static/").to_return(status: 503)

    assert_not Fpl::SyncPayloads.call
    assert_equal 0, Payload.count
  end
end
