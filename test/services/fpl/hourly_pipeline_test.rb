require "test_helper"

class Fpl::HourlyPipelineTest < ActiveSupport::TestCase
  setup do
    Forecast.destroy_all
    # Last week's state, as it stands before this run picks up FPL's rollover.
    gameweeks(:finished).update!(is_current: true)
  end

  # Last season's totals cost a request per player and are covered by their own
  # test; the orchestration is what is being read here. Minitest's mock is not
  # available, so swap the method itself.
  def run_pipeline
    original = Fpl::SyncPlayerHistories.instance_method(:call)
    Fpl::SyncPlayerHistories.define_method(:call) { true }
    Fpl::HourlyPipeline.call
  ensure
    Fpl::SyncPlayerHistories.define_method(:call, original)
  end

  def team(id, name, short_name)
    { "id" => id, "name" => name, "short_name" => short_name, "code" => id, "strength" => 4 }
  end

  def element(id, element_type, team_id, **overrides)
    { "id" => id, "element_type" => element_type, "team" => team_id, "code" => id,
      "first_name" => "Player", "second_name" => id.to_s, "web_name" => "P#{id}", "status" => "a",
      "minutes" => 2700, "now_cost" => 80, "selected_by_percent" => "10.0", "form" => "5.0",
      "points_per_game" => "5.0", "bonus" => 12, "ep_next" => "5.0",
      "expected_goals_per_90" => "0.5", "expected_goal_involvements_per_90" => "0.7",
      "expected_goals_conceded_per_90" => "1.1", "clean_sheets_per_90" => "0.4",
      "saves_per_90" => "3.0", "defensive_contribution_per_90" => "6.0" }.merge(overrides)
  end

  # FPL has finished with gameweek 20 and named 21 as next: exactly the rollover
  # the stale local state above has not caught up with.
  def events
    [ { "id" => 20, "name" => "Gameweek 20", "deadline_time" => 1.week.ago.iso8601, "finished" => true },
      { "id" => 21, "name" => "Gameweek 21", "deadline_time" => 1.day.from_now.iso8601, "is_next" => true },
      { "id" => 22, "name" => "Gameweek 22", "deadline_time" => 2.weeks.from_now.iso8601 } ]
  end

  def bootstrap
    {
      "teams" => [ team(1, "Arsenal", "ARS"), team(2, "Chelsea", "CHE"), team(3, "Liverpool", "LIV") ],
      "elements" => [ element(100, 1, 1), element(200, 3, 3), element(201, 3, 2),
                      element(202, 3, 1), element(203, 4, 3) ],
      "events" => events
    }
  end

  def fixtures
    [ { "id" => 2, "event" => 21, "team_h" => 3, "team_a" => 2, "team_h_difficulty" => 2, "team_a_difficulty" => 4 },
      { "id" => 3, "event" => 21, "team_h" => 1, "team_a" => 2, "team_h_difficulty" => 2, "team_a_difficulty" => 4 } ]
  end

  def stub_fpl(bootstrap_status: 200)
    stub_request(:get, "https://fantasy.premierleague.com/api/bootstrap-static/")
      .to_return(status: bootstrap_status, body: bootstrap.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "https://fantasy.premierleague.com/api/fixtures/")
      .to_return(status: 200, body: fixtures.to_json, headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{/api/event/\d+/live/})
      .to_return(status: 200, body: { "elements" => [] }.to_json, headers: { "Content-Type" => "application/json" })
  end

  test "a clean run reports success and forecasts the coming gameweek" do
    stub_fpl

    assert run_pipeline, "every step succeeded, so the run should report success"
    assert_predicate Forecast.where(gameweek: gameweeks(:next_gw), horizon: "gameweek"), :any?
    assert_predicate Forecast.where(gameweek: gameweeks(:next_gw), horizon: "season"), :any?
  end

  # A legal squad needs fifteen players across at least five clubs, which this stub's
  # small pool cannot field. The search itself is covered by SquadOptimiserTest; what
  # matters here is when the run reaches for it.
  def stored_squad(gameweek)
    Squad.create!(gameweek: gameweek, horizon: "gameweek", formation: "4-4-2",
                  cost: 1000, expected_points: 50.0, picks: [])
  end

  def horizons_searched(gameweek)
    searched = []
    original = SquadOptimiser.method(:call)
    SquadOptimiser.define_singleton_method(:call) { |**args| searched << args[:horizon] }
    Fpl::HourlyPipeline.new.send(:optimise_squads, gameweek)
    searched
  ensure
    SquadOptimiser.define_singleton_method(:call, original)
  end

  # The run happens every hour whether or not football has, and the answer cannot change
  # while its inputs have not.
  test "leaves a squad alone when no forecast has moved since it was written" do
    stub_fpl
    run_pipeline
    gameweek = gameweeks(:next_gw)
    stored_squad(gameweek)
    Forecast.where(gameweek: gameweek).update_all(updated_at: 1.hour.ago)

    assert_equal [ "season" ], horizons_searched(gameweek),
                 "only the horizon without a current squad should be searched again"
  end

  test "searches again once a forecast is newer than the squad" do
    stub_fpl
    run_pipeline
    gameweek = gameweeks(:next_gw)
    stored_squad(gameweek)
    Forecast.where(gameweek: gameweek).update_all(updated_at: 1.minute.from_now)

    assert_includes horizons_searched(gameweek), "gameweek"
  end

  test "files this run's readings against the gameweek this run made current" do
    stub_fpl

    run_pipeline

    assert_equal [ gameweeks(:next_gw).id ], Payload.elements.pluck(:gameweek_id).uniq,
                 "payloads must wait for the gameweek sync, not land on last week's"
    assert_equal [ gameweeks(:next_gw).id ],
                 Statistic.where(type: "season_minutes").pluck(:gameweek_id).uniq
  end

  test "reports failure when a sync cannot reach FPL, having run the rest anyway" do
    stub_fpl(bootstrap_status: 503)

    refute run_pipeline, "a failed sync must not be reported as a healthy run"
    assert_requested :get, %r{/api/event/\d+/live/},
                     at_least_times: 1 # one dead endpoint does not cost the steps after it
  end

  test "wipes last season before syncing when the team list has changed" do
    teams(:arsenal).update!(code: 999)
    stub_fpl

    run_pipeline

    assert_nil Team.find_by(code: 999), "the old season's teams should be gone"
    assert_equal 3, Team.count, "and this season's synced in their place"
  end
end
