require "test_helper"

class Odds::SyncFromCsvTest < ActiveSupport::TestCase
  def setup
    Forecast.delete_all
    Statistic.delete_all
    Performance.delete_all
    Match.delete_all
    Gameweek.delete_all

    @gw = Gameweek.create!(fpl_id: 700, name: "Gameweek 700", start_time: 1.week.ago, is_finished: true)

    @arsenal = teams(:arsenal)
    @liverpool = teams(:liverpool)

    @match = Match.create!(
      fpl_id: 7001,
      home_team: @arsenal,
      away_team: @liverpool,
      gameweek: @gw
    )
  end

  test "updates match odds from CSV data" do
    csv_body = <<~CSV
      HomeTeam,AwayTeam,AvgH,AvgD,AvgA,B365H,B365D,B365A
      Arsenal,Liverpool,2.50,3.20,2.80,2.45,3.25,2.85
    CSV

    stub_request(:get, /football-data\.co\.uk/).to_return(status: 200, body: csv_body)

    result = Odds::SyncFromCsv.call

    assert_equal 1, result[:matched]
    assert_equal 0, result[:unmatched]

    @match.reload
    assert_equal 2.50, @match.odds_home_win.to_f
    assert_equal 3.20, @match.odds_draw.to_f
    assert_equal 2.80, @match.odds_away_win.to_f
  end

  test "handles team name mapping" do
    spurs = Team.find_or_create_by!(fpl_id: 700) { |t| t.name = "Spurs"; t.short_name = "TOT" }
    man_utd = Team.find_or_create_by!(fpl_id: 701) { |t| t.name = "Man Utd"; t.short_name = "MUN" }
    Match.create!(fpl_id: 7002, home_team: spurs, away_team: man_utd, gameweek: @gw)

    csv_body = <<~CSV
      HomeTeam,AwayTeam,AvgH,AvgD,AvgA
      Tottenham,Man United,1.80,3.50,4.20
    CSV

    stub_request(:get, /football-data\.co\.uk/).to_return(status: 200, body: csv_body)

    result = Odds::SyncFromCsv.call

    assert_equal 1, result[:matched]
  end

  test "reports unmatched rows" do
    csv_body = <<~CSV
      HomeTeam,AwayTeam,AvgH,AvgD,AvgA
      Unknown FC,Mystery United,2.00,3.00,4.00
    CSV

    stub_request(:get, /football-data\.co\.uk/).to_return(status: 200, body: csv_body)

    result = Odds::SyncFromCsv.call

    assert_equal 0, result[:matched]
    assert_equal 1, result[:unmatched]
  end

  test "handles HTTP failure" do
    stub_request(:get, /football-data\.co\.uk/).to_return(status: 500)

    result = Odds::SyncFromCsv.call

    assert_equal 0, result[:matched]
    assert_equal 0, result[:unmatched]
    assert result[:error].present?
  end

  test "falls back to B365 odds when Avg odds missing" do
    csv_body = <<~CSV
      HomeTeam,AwayTeam,B365H,B365D,B365A
      Arsenal,Liverpool,2.10,3.30,3.50
    CSV

    stub_request(:get, /football-data\.co\.uk/).to_return(status: 200, body: csv_body)

    result = Odds::SyncFromCsv.call

    assert_equal 1, result[:matched]
    @match.reload
    assert_equal 2.10, @match.odds_home_win.to_f
  end

  test "accepts custom season parameter" do
    csv_body = "HomeTeam,AwayTeam,AvgH,AvgD,AvgA\n"
    stub_request(:get, %r{football-data\.co\.uk/mmz4281/2425/E0\.csv}).to_return(status: 200, body: csv_body)

    result = Odds::SyncFromCsv.call(season: "2425")

    assert_equal 0, result[:matched]
    assert_equal 0, result[:unmatched]
  end
end
