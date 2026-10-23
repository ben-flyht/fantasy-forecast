require "csv"

module History
  class Season
    POSITIONS = { "1" => "goalkeeper", "2" => "defender", "3" => "midfielder", "4" => "forward" }.freeze
    SQUAD_SIZE = 15
    FORM_WINDOW = 30.days
    DEADLINE_LEAD = 90.minutes
    MOVER_WINDOW = 120.days
    FULL_MATCH = ExpectedPoints::FULL_MATCH

    RATES = {
      "expected_goals" => "expected_goals_per_90",
      "expected_assists" => "expected_assists_per_90",
      "expected_goals_conceded" => "expected_goals_conceded_per_90",
      "saves" => "saves_per_90",
      "defensive_contribution" => "defensive_contribution_per_90"
    }.freeze

    attr_reader :teams

    def self.from_directory(dir, previous: nil)
      new(rows: read(dir, "merged_gw.csv"), players: read(dir, "players_raw.csv"),
          fixtures: read(dir, "fixtures.csv"), teams: read(dir, "teams.csv"),
          previous_players: previous ? read(previous, "players_raw.csv") : [])
    end

    def self.read(dir, name)
      path = [ File.join(dir, name), File.join(dir, "gws", name) ].find { |candidate| File.exist?(candidate) }
      raise ArgumentError, "#{name} not found in #{dir}" unless path

      CSV.read(path, headers: true, encoding: "bom|utf-8").map(&:to_h)
    end

    def initialize(rows:, players:, fixtures:, teams:, previous_players: [])
      @players = playable(players)
      @fixtures = scheduled(fixtures)
      @teams = teams.to_h { |team| [ team["id"].to_i, team["name"] ] }
      @previous = previous_players.index_by { |player| player["code"].to_s }
      @appearances = appearances(rows)
    end

    def rounds
      @rounds ||= @fixtures.values.map { |fixture| fixture["event"].to_i }.uniq.sort
    end

    def deadline(round)
      kickoffs = @fixtures.values.select { |fixture| fixture["event"].to_i == round }
                          .map { |fixture| Time.zone.parse(fixture["kickoff_time"]) }
      kickoffs.min - DEADLINE_LEAD
    end

    def inputs(round, recent_gameweeks: Forecaster::RECENT_GAMEWEEKS)
      played = round - 1
      {
        rankings: squad(round),
        stats: stats(round, recent_gameweeks),
        gameweeks_played: played,
        season_started: played.positive?,
        managers: played.positive? ? managers(round) : 0,
        movers: movers(round)
      }
    end

    def squad(round)
      present(round).map do |element|
        ConsensusRanking::Ranking.new(player_id: element, position: position(element), team_id: team_at(element, round))
      end
    end

    def position(element)
      POSITIONS.fetch(@players.fetch(element)["element_type"].to_s)
    end

    def name(element)
      @players.dig(element, "web_name")
    end

    def stats(round, recent_gameweeks = Forecaster::RECENT_GAMEWEEKS)
      before = @appearances.select { |row| row.round < round }.group_by(&:element)
      recent = recent_rounds(round, recent_gameweeks)
      present(round).to_h do |element|
        [ element, record_for(element, round, before.fetch(element, []), recent) ]
      end
    end

    def managers(round)
      @managers ||= {}
      @managers[round] ||= market_rows(round).values.sum { |row| row.selected.to_f } / SQUAD_SIZE
    end

    def movers(round)
      deadline = deadline(round)
      present(round).select do |element|
        joined = joined_on(element)
        joined && joined <= deadline.to_date && joined >= (deadline - MOVER_WINDOW).to_date
      end
    end

    def fixtures_by_team(rounds, difficulty: nil)
      matches(rounds).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |fixture, by_team|
        home, away = fixture.values_at("team_h", "team_a").map(&:to_i)
        by_team[home] << fixture_for(fixture, home, away, true, difficulty)
        by_team[away] << fixture_for(fixture, away, home, false, difficulty)
      end
    end

    def matches(rounds)
      window = Array(rounds)
      @fixtures.values.select { |fixture| window.include?(fixture["event"].to_i) }
    end

    def fixture(id)
      @fixtures[id]
    end

    def points(rounds)
      total(rounds, &:points)
    end

    def minutes(rounds)
      total(rounds, &:minutes)
    end

    private

    def playable(players)
      players.select { |player| POSITIONS.key?(player["element_type"].to_s) }.index_by { |player| player["id"].to_i }
    end

    def scheduled(fixtures)
      fixtures.select { |fixture| fixture["event"].present? }.index_by { |fixture| fixture["id"].to_i }
    end

    def appearances(rows)
      rows.filter_map do |row|
        fixture = @fixtures[row["fixture"].to_i]
        Appearance.from_row(row, fixture) if fixture && @players.key?(row["element"].to_i)
      end.sort_by { |row| [ row.round, row.kickoff ] }
    end

    def record_for(element, round, played, recent)
      record = season_record(played, round).merge(market(element, round)).merge(last_season(element))
      record[ExpectedPoints::RECENT_MINUTES] = recent_share(played, recent) if recent.any?
      record
    end

    def joined_on(element)
      Date.iso8601(@players[element]["team_join_date"].to_s)
    rescue Date::Error
      nil
    end

    def present(round)
      @present ||= {}
      @present[round] ||= spans.select { |_, (first, last)| first <= round && round <= last }.keys.sort
    end

    def spans
      @spans ||= @appearances.group_by(&:element).transform_values { |rows| rows.map(&:round).minmax }
    end

    def team_at(element, round)
      market_rows(round)[element]&.team_id
    end

    def market_rows(round)
      @market_rows ||= {}
      @market_rows[round] ||= @appearances.select { |row| row.round <= round }
                                          .group_by(&:element)
                                          .transform_values(&:last)
                                          .slice(*present(round))
    end

    def season_record(played, round)
      { "season_minutes" => played.sum(&:minutes), "season_bonus" => played.sum(&:bonus),
        "form" => form(played, round), "points_per_game" => points_per_game(played) }.merge(season_rates(played))
    end

    def season_rates(played)
      minutes = played.sum(&:minutes)
      RATES.each_with_object({}) do |(stat, type), rates|
        values = played.map { |row| row.rates[stat] }.compact
        next if values.empty? && played.any?

        rates[type] = minutes.positive? ? values.sum / minutes * FULL_MATCH : 0.0
      end
    end

    def form(played, round)
      deadline = deadline(round)
      window = played.select { |row| row.kickoff >= deadline - FORM_WINDOW }
      return 0.0 if window.empty?

      window.sum(&:points) / window.size
    end

    def points_per_game(played)
      appeared = played.select { |row| row.minutes.positive? }
      return 0.0 if appeared.empty?

      appeared.sum(&:points) / appeared.size
    end

    def market(element, round)
      row = market_rows(round)[element]
      this_week = row&.round == round
      {
        "now_cost" => row&.value.to_f,
        "selected_by_percent" => row&.selected.to_f / managers(round) * 100,
        "transfers_in" => this_week ? row.transfers_in : 0.0,
        "transfers_out" => this_week ? row.transfers_out : 0.0
      }
    end

    def last_season(element)
      before = @previous[@players[element]["code"].to_s]
      return {} unless before

      { "last_season_minutes" => before["minutes"].to_f, "last_season_points" => before["total_points"].to_f,
        "last_season_bonus" => before["bonus"].to_f }.merge(last_season_rates(before))
    end

    def last_season_rates(before)
      minutes = before["minutes"].to_f
      return {} unless minutes.positive?

      RATES.select { |stat, _| before[stat].present? }
           .to_h { |stat, type| [ "last_season_#{type}", before[stat].to_f / minutes * FULL_MATCH ] }
    end

    def recent_rounds(round, weeks)
      return [] unless weeks.positive?

      rounds.select { |candidate| candidate >= round - weeks && candidate < round }
    end

    def recent_share(played, recent)
      played.select { |row| recent.include?(row.round) }.sum(&:minutes) / (recent.size * FULL_MATCH)
    end

    def total(rounds)
      window = Array(rounds)
      @appearances.select { |row| window.include?(row.round) }
                  .each_with_object(Hash.new(0.0)) { |row, totals| totals[row.element] += yield(row) }
    end

    def fixture_for(fixture, team, opponent, home, difficulty)
      rated = { difficulty: fixture[home ? "team_h_difficulty" : "team_a_difficulty"]&.to_f }
      rated = rated.merge(difficulty.call(fixture, team, rated[:difficulty])) if difficulty
      rated.merge(opponent: @teams[opponent], home: home, fixture: fixture["id"].to_i)
    end
  end
end
