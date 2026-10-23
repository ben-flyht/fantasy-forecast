require "test_helper"

module History
  class SeasonTest < ActiveSupport::TestCase
    KICKOFFS = { 1 => "2025-08-16T14:00:00Z", 2 => "2025-08-23T14:00:00Z",
                 3 => "2025-08-30T14:00:00Z", 4 => "2025-09-20T14:00:00Z" }.freeze

    setup do
      @season = Season.new(rows: rows, players: players, fixtures: fixtures, teams: teams,
                           previous_players: previous_players)
    end

    def teams
      [ { "id" => "1", "name" => "Alpha" }, { "id" => "2", "name" => "Beta" } ]
    end

    def fixtures
      KICKOFFS.map do |round, kickoff|
        home, away = round.odd? ? %w[1 2] : %w[2 1]
        { "id" => round.to_s, "event" => round.to_s, "kickoff_time" => kickoff, "team_h" => home, "team_a" => away,
          "team_h_difficulty" => "2", "team_a_difficulty" => "4", "team_h_score" => "1", "team_a_score" => "0" }
      end
    end

    def players
      [ { "id" => "10", "code" => "100", "element_type" => "4", "web_name" => "Striker", "team_join_date" => "2025-07-01" },
        { "id" => "11", "code" => "101", "element_type" => "2", "web_name" => "Back", "team_join_date" => "2020-01-01" },
        { "id" => "12", "code" => "102", "element_type" => "3", "web_name" => "Gone", "team_join_date" => "None" },
        { "id" => "13", "code" => "103", "element_type" => "5", "web_name" => "Boss", "team_join_date" => "2025-07-01" } ]
    end

    def previous_players
      [ { "code" => "100", "minutes" => "2700", "total_points" => "150", "bonus" => "20", "expected_goals" => "15.0",
          "expected_assists" => "4.5", "expected_goals_conceded" => "30.0", "saves" => "0" } ]
    end

    def rows
      striker = [ [ 90, 8, 3, 0.5, 1000, 80, 10, 0 ], [ 45, 2, 0, 0.2, 2000, 81, 900, 0 ],
                  [ 0, 0, 0, 0.0, 3000, 81, 0, 600 ], [ 90, 5, 1, 0.4, 4000, 82, 50, 70 ] ]
      striker.each_with_index.map { |values, index| row(10, index + 1, *values) } +
        (1..4).map { |round| row(11, round, 90, 1, 0, 0.0, 500, 45, 0, 0) } +
        (1..2).map { |round| row(12, round, 90, 2, 0, 0.1, 1500, 50, 0, 0) } +
        (1..4).map { |round| row(13, round, 0, 0, 0, 0.0, 99_999, 5, 0, 0) }
    end

    def row(element, round, minutes, points, bonus, expected_goals, selected, value, transfers_in, transfers_out)
      { "element" => element.to_s, "round" => round.to_s, "fixture" => round.to_s,
        "was_home" => (round.odd? ? "True" : "False"), "kickoff_time" => KICKOFFS.fetch(round),
        "minutes" => minutes.to_s, "total_points" => points.to_s, "bonus" => bonus.to_s,
        "expected_goals" => expected_goals.to_s, "expected_assists" => "0.1", "expected_goals_conceded" => "1.0",
        "saves" => "0", "defensive_contribution" => "6", "selected" => selected.to_s, "value" => value.to_s,
        "transfers_in" => transfers_in.to_s, "transfers_out" => transfers_out.to_s }
    end

    test "the deadline is ninety minutes before the gameweek's first kickoff" do
      assert_equal Time.utc(2025, 8, 16, 12, 30), @season.deadline(1)
    end

    test "the squad is everyone registered that week, managers aside, on the club they play for then" do
      squad = @season.squad(4)

      assert_equal [ 10, 11 ], squad.map(&:player_id)
      assert_equal %w[forward defender], squad.map(&:position)
      assert_equal [ 1, 1 ], squad.map(&:team_id)
    end

    test "a player who has left the league drops out of the squad" do
      assert_includes @season.squad(2).map(&:player_id), 12
      assert_not_includes @season.squad(3).map(&:player_id), 12
    end

    test "the season record is built only from gameweeks before the one being forecast" do
      stats = @season.stats(4)[10]

      assert_equal 135.0, stats["season_minutes"]
      assert_equal 3.0, stats["season_bonus"]
      assert_in_delta 0.7 / 135 * 90, stats["expected_goals_per_90"]
      assert_in_delta 0.3 / 135 * 90, stats["expected_assists_per_90"]
      assert_in_delta 18.0 / 135 * 90, stats["defensive_contribution_per_90"]
    end

    test "what happens in the gameweek itself never reaches its forecast" do
      later = rows.map { |row| row["round"] == "4" ? row.merge("minutes" => "0", "total_points" => "20", "expected_goals" => "3") : row }
      changed = Season.new(rows: later, players: players, fixtures: fixtures, teams: teams, previous_players: previous_players)

      assert_equal @season.stats(4), changed.stats(4)
    end

    test "price, ownership and this week's traffic are read as they stood at the deadline" do
      stats = @season.stats(4)[10]
      managers = (4000 + 500) / 15.0

      assert_equal 82.0, stats["now_cost"]
      assert_in_delta 4000 / managers * 100, stats["selected_by_percent"]
      assert_equal 50.0, stats["transfers_in"]
      assert_equal 70.0, stats["transfers_out"]
      assert_in_delta managers, @season.managers(4)
    end

    test "form is points per match over the thirty days before the deadline, and points per game counts appearances" do
      stats = @season.stats(4)[10]

      assert_in_delta (2 + 0) / 2.0, stats["form"], 0.001, "gameweek 1 kicked off more than thirty days before gameweek 4"
      assert_equal 5.0, stats["points_per_game"], "the match he did not play is not a game"
    end

    test "recent minutes are a share of the last few gameweeks' football" do
      assert_in_delta 135.0 / 270, @season.stats(4, 3)[10][ExpectedPoints::RECENT_MINUTES]
      assert_in_delta 45.0 / 180, @season.stats(4, 2)[10][ExpectedPoints::RECENT_MINUTES]
      assert_not @season.stats(4, 0)[10].key?(ExpectedPoints::RECENT_MINUTES)
      assert_not @season.stats(1)[10].key?(ExpectedPoints::RECENT_MINUTES)
    end

    test "last season is matched on the player's code and read per 90" do
      stats = @season.stats(4)[10]

      assert_equal 2700.0, stats["last_season_minutes"]
      assert_equal 150.0, stats["last_season_points"]
      assert_equal 20.0, stats["last_season_bonus"]
      assert_in_delta 0.5, stats["last_season_expected_goals_per_90"]
      assert_not stats.key?("last_season_defensive_contribution_per_90"), "a column last season did not have stays silent"
      assert_not @season.stats(4)[11].key?("last_season_minutes")
    end

    test "before a ball is kicked the record is empty and nobody's traffic counts" do
      inputs = @season.inputs(1)

      assert_equal 0, inputs[:gameweeks_played]
      assert_not inputs[:season_started]
      assert_equal 0, inputs[:managers]
      assert_equal 0.0, inputs[:stats][10]["season_minutes"]
      assert_equal 0.0, inputs[:stats][10]["expected_goals_per_90"]
    end

    test "a summer signing is a mover until four months after he joined" do
      assert_equal [ 10 ], @season.movers(1)
      assert_equal [ 10 ], @season.inputs(4)[:movers]
    end

    test "fixtures carry FDR from the side's own point of view" do
      fixtures = @season.fixtures_by_team([ 1, 2 ])

      assert_equal [ 2.0, 4.0 ], fixtures[1].map { |fixture| fixture[:difficulty] }
      assert_equal [ "Beta", "Beta" ], fixtures[1].map { |fixture| fixture[:opponent] }
      assert_equal [ true, false ], fixtures[1].map { |fixture| fixture[:home] }
    end

    test "another rating can stand in for FDR" do
      fixtures = @season.fixtures_by_team([ 1 ], difficulty: ->(_fixture, team, fdr) { { difficulty: fdr + team } })

      assert_equal 3.0, fixtures[1].first[:difficulty]
      assert_equal 6.0, fixtures[2].first[:difficulty]
    end

    test "actual points and minutes are summed over the window" do
      assert_equal 5.0, @season.points([ 3, 4 ])[10]
      assert_equal 90.0, @season.minutes([ 3, 4 ])[10]
      assert_equal 0.0, @season.points([ 3, 4 ])[12]
    end

    test "the inputs are what ExpectedPoints takes" do
      inputs = @season.inputs(4)
      forecasts = ExpectedPoints.call(inputs[:rankings], stats: inputs[:stats], fixtures_by_team: @season.fixtures_by_team([ 4 ]),
                                      season_started: inputs[:season_started], gameweeks_played: inputs[:gameweeks_played],
                                      managers: inputs[:managers], movers: inputs[:movers])

      assert forecasts[10][:points].positive?
      assert forecasts[11][:points].positive?
    end
  end
end
