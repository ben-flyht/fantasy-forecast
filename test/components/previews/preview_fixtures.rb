# frozen_string_literal: true

module PreviewFixtures
  TEAMS = {
    arsenal: { id: 1, name: "Arsenal", short_name: "ARS", code: 3 },
    city: { id: 2, name: "Man City", short_name: "MCI", code: 43 },
    liverpool: { id: 3, name: "Liverpool", short_name: "LIV", code: 14 },
    newcastle: { id: 4, name: "Newcastle", short_name: "NEW", code: 4 },
    chelsea: { id: 5, name: "Chelsea", short_name: "CHE", code: 8 }
  }.freeze

  PLAYERS = {
    haaland: { id: 1, first_name: "Erling", last_name: "Haaland", short_name: "Haaland", position: "forward",
               code: 223094, team: :city, birth_date: Date.new(2000, 7, 21) },
    salah: { id: 2, first_name: "Mohamed", last_name: "Salah", short_name: "M.Salah", position: "midfielder",
             code: 118748, team: :liverpool, birth_date: Date.new(1992, 6, 15) },
    saka: { id: 3, first_name: "Bukayo", last_name: "Saka", short_name: "Saka", position: "midfielder",
            code: 223340, team: :arsenal, birth_date: Date.new(2001, 9, 5) },
    palmer: { id: 4, first_name: "Cole", last_name: "Palmer", short_name: "Palmer", position: "midfielder",
              code: 244851, team: :chelsea, birth_date: Date.new(2002, 5, 6) },
    gabriel: { id: 5, first_name: "Gabriel", last_name: "dos Santos Magalhães", short_name: "Gabriel",
               position: "defender", code: 226597, team: :arsenal, birth_date: Date.new(1997, 12, 19) },
    pope: { id: 6, first_name: "Nick", last_name: "Pope", short_name: "Pope", position: "goalkeeper",
            code: 98747, team: :newcastle, birth_date: Date.new(1992, 4, 19) },
    unknown: { id: 7, first_name: "Trialist", last_name: "Unattached", short_name: "Unattached",
               position: "forward", code: nil, team: nil, birth_date: nil }
  }.freeze

  FACTS = {
    haaland: { "now_cost" => 145, "selected_by_percent" => 62.4, "transfers_in" => 184_000, "transfers_out" => 21_000 },
    salah: { "now_cost" => 140, "selected_by_percent" => 38.1, "transfers_in" => 12_000, "transfers_out" => 96_000 },
    saka: { "now_cost" => 100, "selected_by_percent" => 24.7, "transfers_in" => 800, "transfers_out" => 800 },
    palmer: { "now_cost" => 105, "selected_by_percent" => 31.0 },
    gabriel: { "now_cost" => 62, "selected_by_percent" => 18.3 },
    pope: { "now_cost" => 51, "selected_by_percent" => 9.6 },
    unknown: {}
  }.freeze

  GRADES = %w[A A B B C D].freeze

  Comparison = Struct.new(:alternatives, :upgrade, :ceiling, :score, :beaten_by, keyword_init: true) do
    alias_method :upgrade?, :upgrade
  end

  History = Struct.new(:ranks, :rank_change, :played, :trends, :total_points, :points_per_million, :best_week,
                       :appearances, :blanks, :price_history, keyword_init: true) do
    alias_method :played?, :played
  end

  Fixture = Struct.new(:fpl_id, :start_time)

  LAST_SEASON = {
    "last_season_points" => 244, "last_season_minutes" => 2984, "last_season_starts" => 34,
    "last_season_assists" => 11, "last_season_bonus" => 28, "last_season_goals_per_90" => 0.66,
    "last_season_expected_goals_per_90" => 0.71, "last_season_expected_assists_per_90" => 0.24,
    "last_season_clean_sheets_per_90" => 0.31, "last_season_saves_per_90" => 0,
    "last_season_defensive_contribution_per_90" => 4.2
  }.freeze

  WORKING = {
    ours: 6.42, crowd: 5.88, per_90: 6.91, minutes: 84, perf_factor: 1.09, form: 1.06, transfers: 1.03,
    calibration: 0.97, games: 1.08,
    opponents: [ { name: "Fulham", home: true, difficulty: 2 } ]
  }.freeze

  module_function

  def team(key)
    Team.new(**TEAMS.fetch(key))
  end

  def player(key)
    attributes = PLAYERS.fetch(key)
    Player.new(**attributes.except(:team), fpl_id: attributes[:id], team: (team(attributes[:team]) if attributes[:team]))
  end

  def facts(key) = FACTS.fetch(key)

  def ranking(key, rank: 1, grade: "A", score: 7.4, tier: 1)
    subject = player(key)
    ConsensusRanking::Ranking.new(player_id: subject.id, name: subject.display_name, team_id: subject.team_id,
                                  position: subject.position, bot_rank: rank, score: score, tier: tier, grade: grade)
  end

  def entry(key, rank: 1, grade: "A", **options)
    { ranking: ranking(key, rank: rank, grade: grade), player: player(key), facts: facts(key), **options }
  end

  def entries(keys = %i[haaland salah saka palmer gabriel pope])
    keys.each_with_index.map { |key, index| entry(key, rank: index + 1, grade: GRADES[index]) }
  end

  def option(key, place:, score:, subject: false, of: 11, grade: "B")
    PlayerComparison::Entry.new(player: player(key), score: score, rank: place, cost: facts(key)["now_cost"],
                                subject: subject, place: place, of: of, grade: grade, facts: facts(key))
  end

  def options
    [
      option(:haaland, place: 1, score: 7.4),
      option(:salah, place: 2, score: 6.9),
      option(:saka, place: 3, score: 6.1, subject: true),
      option(:palmer, place: 7, score: 4.8)
    ]
  end

  def comparison(upgrade: true)
    Comparison.new(
      alternatives: [ option(:haaland, place: 1, score: 7.4, grade: "A"), option(:salah, place: 2, score: 6.9, grade: "A"),
                      option(:palmer, place: 3, score: 5.2) ],
      upgrade: upgrade, ceiling: 145, score: 6.1, beaten_by: upgrade ? [ 2, 14 ] : [ 0, 14 ]
    )
  end

  def points(*values)
    values.each_with_index.map { |value, index| PlayerHistory::Point.new(gameweek: 6 + index, value: value) }
  end

  def history(ranks: [ 26, 12 ], price: [ 143, 145 ])
    series = points(*ranks)
    History.new(
      ranks: series, rank_change: (series[-2].value - series[-1].value if series.many?), played: true,
      trends: [ PlayerHistory::Trend.new(label: "Expected goals per 90", points: points(0.61, 0.74)),
                PlayerHistory::Trend.new(label: "Expected assists per 90", points: points(0.22, 0.19)) ],
      total_points: 78, points_per_million: 5.4, best_week: PlayerHistory::Point.new(gameweek: 4, value: 17),
      appearances: Array.new(8), blanks: 2, price_history: PlayerHistory::Trend.new(label: "Price", points: points(*price))
    )
  end

  def fixtures(scored: true)
    [ [ 11, :arsenal, true, 9 ], [ 12, :newcastle, false, 2 ], [ 13, :chelsea, true, 6.4 ] ].map do |week, opponent, home, score|
      { gameweek: Fixture.new(week, Time.zone.local(2026, 11, week + 3, 15)), opponent: team(opponent), home: home,
        points: (score if scored) }
    end
  end

  def form(scores)
    opponents = %i[liverpool arsenal chelsea newcastle city]
    scores.each_with_index.map do |score, index|
      { gameweek: Fixture.new(6 + index, nil), opponent: team(opponents[index]), home: index.even?, points: score }
    end
  end

  def card(key, fixtures: [ "FUL (H)" ])
    Pack::Card.new(player: player(key), rank: 1, expected_points: 6.4, fixtures: fixtures)
  end
end
