module ApiFootball
  class ExpectedGoalsCalculator
    HOME_TEAM_EXACT_GOALS_BET_ID = 40
    AWAY_TEAM_EXACT_GOALS_BET_ID = 41

    # For "more X" outcomes, assume average of X+0.5 goals
    MORE_GOALS_OFFSET = 0.5

    def self.call(odds_data:, bookmaker: nil)
      new(odds_data: odds_data, bookmaker: bookmaker).call
    end

    def initialize(odds_data:, bookmaker: nil)
      @odds_data = odds_data
      @bookmaker = bookmaker
    end

    def call
      return [ nil, nil ] if @odds_data.nil? || @odds_data.empty?

      bookmaker_data = select_bookmaker
      return [ nil, nil ] unless bookmaker_data

      home_bets = find_bet(bookmaker_data, HOME_TEAM_EXACT_GOALS_BET_ID)
      away_bets = find_bet(bookmaker_data, AWAY_TEAM_EXACT_GOALS_BET_ID)

      return [ nil, nil ] unless home_bets && away_bets

      home_xg = calculate_xg(home_bets["values"])
      away_xg = calculate_xg(away_bets["values"])

      return [ nil, nil ] unless home_xg && away_xg

      [ home_xg.round(2), away_xg.round(2) ]
    end

    private

    def select_bookmaker
      bookmakers = @odds_data.first&.dig("bookmakers")
      return nil unless bookmakers&.any?

      # Prefer specified bookmaker, or find one with our required bets
      if @bookmaker
        bookmakers.find { |b| b["key"] == @bookmaker || b["name"] == @bookmaker }
      else
        # Prefer Bet365, then any bookmaker with the required markets
        bookmakers.find { |b| b["name"] == "Bet365" && has_required_bets?(b) } ||
          bookmakers.find { |b| has_required_bets?(b) }
      end
    end

    def has_required_bets?(bookmaker)
      bets = bookmaker["bets"]
      return false unless bets

      bets.any? { |b| b["id"] == HOME_TEAM_EXACT_GOALS_BET_ID } &&
        bets.any? { |b| b["id"] == AWAY_TEAM_EXACT_GOALS_BET_ID }
    end

    def find_bet(bookmaker, bet_id)
      bookmaker["bets"]&.find { |b| b["id"] == bet_id }
    end

    def calculate_xg(values)
      return nil if values.nil? || values.empty?

      probabilities = convert_to_probabilities(values)
      return nil if probabilities.empty?

      # Normalize probabilities to sum to 1 (remove bookmaker overround)
      total_prob = probabilities.values.sum
      return nil if total_prob.zero?

      normalized = probabilities.transform_values { |p| p / total_prob }

      # Calculate expected value: sum of (goals * probability)
      normalized.sum { |goals, prob| goals * prob }
    end

    def convert_to_probabilities(values)
      probabilities = {}

      values.each do |outcome|
        goals = parse_goals(outcome["value"])
        next unless goals

        odd = outcome["odd"].to_f
        next if odd <= 1.0

        # Implied probability = 1 / decimal odds
        probabilities[goals] = 1.0 / odd
      end

      probabilities
    end

    def parse_goals(value)
      case value
      when Integer
        value.to_f
      when /^\d+$/
        value.to_i.to_f
      when /^more\s*(\d+)$/i
        # "more 3" means 3+ goals, use 3.5 as expected value for this bucket
        $1.to_i + MORE_GOALS_OFFSET
      else
        nil
      end
    end
  end
end
