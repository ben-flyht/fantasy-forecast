module History
  class FixtureRatings
    SIDES = { home: %w[team_h team_h_difficulty team_h_score team_a_score],
              away: %w[team_a team_a_difficulty team_a_score team_h_score] }.freeze

    def initialize(season, odds)
      @season = season
      @odds = odds
      @fdr = sides.map { |side| side[:fdr] }
    end

    def odds
      single = scale(sides.map { |side| side[:against] - side[:for] })
      rated { |key| { difficulty: single[key] } }
    end

    def split
      attack = scale(sides.map { |side| -side[:for] })
      defence = scale(sides.map { |side| side[:against] })
      rated { |key| { attack: attack[key], defence: defence[key] } }
    end

    def sides
      @sides ||= @season.matches(@season.rounds).flat_map do |fixture|
        expected = expected_for(fixture)
        next [] unless expected

        [ side(fixture, :home, expected), side(fixture, :away, expected.reverse) ]
      end
    end

    private

    def side(fixture, venue, expected)
      team, rating, scored, conceded = SIDES.fetch(venue).map { |column| fixture[column] }
      { key: [ fixture["id"].to_i, team.to_i ], for: Math.log(expected.first), against: Math.log(expected.last),
        fdr: rating.to_f, expected: expected, goals: scored.to_i, conceded: conceded.to_i }
    end

    def expected_for(fixture)
      @odds.expected_goals(@season.teams[fixture["team_h"].to_i], @season.teams[fixture["team_a"].to_i])
    end

    def scale(scores)
      mean, spread = moments(scores)
      fdr_mean, fdr_spread = moments(@fdr)
      sides.each_with_index.to_h do |side, index|
        [ side[:key], fdr_mean + fdr_spread * (scores[index] - mean) / spread ]
      end
    end

    def moments(values)
      mean = values.sum / values.size
      [ mean, Math.sqrt(values.sum { |value| (value - mean)**2 } / values.size) ]
    end

    def rated(&rating)
      ratings = {}
      lambda do |fixture, team, _fdr|
        key = [ fixture["id"].to_i, team ]
        ratings[key] ||= rating.call(key)
        ratings[key].compact
      end
    end
  end
end
