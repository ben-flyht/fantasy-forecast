require "csv"

module History
  class Odds
    TEAM_NAMES = { "Man United" => "Man Utd", "Tottenham" => "Spurs" }.freeze
    MOST_GOALS = 12
    OVER_LINE = 3
    SEARCH_STEPS = 60
    PRICES = { home_win: "AvgH", draw: "AvgD", away_win: "AvgA", over: "Avg>2.5", under: "Avg<2.5" }.freeze

    Match = Struct.new(:home, :away, :home_expected, :away_expected, keyword_init: true)

    def self.from_file(path)
      new(CSV.read(path, headers: true, encoding: "bom|utf-8").map(&:to_h))
    end

    def initialize(rows)
      @matches = rows.filter_map { |row| match(row) }.index_by { |match| [ match.home, match.away ] }
    end

    def find(home, away)
      @matches[[ home, away ]]
    end

    def matches
      @matches.values
    end

    def expected_goals(home, away)
      match = find(home, away)
      match && [ match.home_expected, match.away_expected ]
    end

    def self.implied_goals(home_win:, draw:, away_win:, over:, under:)
      home, _, away = fair([ home_win, draw, away_win ])
      total = total_goals(fair([ over, under ]).first)
      share = home_share(total, home - away)
      [ total * share, total * (1 - share) ]
    end

    def self.fair(prices)
      chances = prices.map { |price| 1.0 / price }
      chances.map { |chance| chance / chances.sum }
    end

    def self.total_goals(over)
      bisect(0.05, 8.0) { |total| 1 - (0...OVER_LINE).sum { |goals| poisson(total, goals) } > over }
    end

    def self.home_share(total, edge)
      bisect(0.01, 0.99) { |share| margin(total * share, total * (1 - share)) > edge }
    end

    def self.margin(home, away)
      (0..MOST_GOALS).sum do |home_goals|
        (0..MOST_GOALS).sum do |away_goals|
          chance = poisson(home, home_goals) * poisson(away, away_goals)
          (home_goals <=> away_goals) * chance
        end
      end
    end

    def self.poisson(rate, goals)
      Math.exp(-rate) * rate**goals / (1..goals).reduce(1, :*)
    end

    def self.bisect(low, high)
      SEARCH_STEPS.times do
        middle = (low + high) / 2
        yield(middle) ? high = middle : low = middle
      end
      (low + high) / 2
    end

    private

    def match(row)
      prices = PRICES.transform_values { |column| row[column] }
      return nil if prices.values.any?(&:blank?)

      home, away = self.class.implied_goals(**prices.transform_values(&:to_f))
      Match.new(home: team(row["HomeTeam"]), away: team(row["AwayTeam"]), home_expected: home, away_expected: away)
    end

    def team(name)
      TEAM_NAMES.fetch(name, name)
    end
  end
end
