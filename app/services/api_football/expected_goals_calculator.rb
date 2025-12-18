module ApiFootball
  class ExpectedGoalsCalculator < ApplicationService
    HOME_TEAM_EXACT_GOALS_BET_ID = 40
    AWAY_TEAM_EXACT_GOALS_BET_ID = 41

    # For "more X" outcomes, assume average of X+0.5 goals
    MORE_GOALS_OFFSET = 0.5

    def initialize(odds_data:, bookmaker: nil)
      @odds_data = odds_data
      @bookmaker = bookmaker
    end

    def call
      return [ nil, nil ] if @odds_data.nil? || @odds_data.empty?

      bookmaker_data = select_bookmaker
      return [ nil, nil ] unless bookmaker_data

      calculate_team_xg(bookmaker_data)
    end

    private

    def calculate_team_xg(bookmaker_data)
      home_bets = find_bet(bookmaker_data, HOME_TEAM_EXACT_GOALS_BET_ID)
      away_bets = find_bet(bookmaker_data, AWAY_TEAM_EXACT_GOALS_BET_ID)
      return [ nil, nil ] unless home_bets && away_bets

      home_xg = calculate_xg(home_bets["values"])
      away_xg = calculate_xg(away_bets["values"])
      return [ nil, nil ] unless home_xg && away_xg

      [ home_xg.round(2), away_xg.round(2) ]
    end

    def select_bookmaker
      bookmakers = @odds_data.first&.dig("bookmakers")
      return nil unless bookmakers&.any?

      @bookmaker ? find_specified_bookmaker(bookmakers) : find_default_bookmaker(bookmakers)
    end

    def find_specified_bookmaker(bookmakers)
      bookmakers.find { |b| b["key"] == @bookmaker || b["name"] == @bookmaker }
    end

    def find_default_bookmaker(bookmakers)
      find_bet365(bookmakers) || find_any_with_required_bets(bookmakers)
    end

    def find_bet365(bookmakers)
      bookmakers.find { |b| b["name"] == "Bet365" && has_required_bets?(b) }
    end

    def find_any_with_required_bets(bookmakers)
      bookmakers.find { |b| has_required_bets?(b) }
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

      normalize_and_calculate_expected_value(probabilities)
    end

    def normalize_and_calculate_expected_value(probabilities)
      total_prob = probabilities.values.sum
      return nil if total_prob.zero?

      normalized = probabilities.transform_values { |p| p / total_prob }
      normalized.sum { |goals, prob| goals * prob }
    end

    def convert_to_probabilities(values)
      values.each_with_object({}) do |outcome, probs|
        goals = parse_goals(outcome["value"])
        next unless goals

        odd = outcome["odd"].to_f
        probs[goals] = 1.0 / odd if odd > 1.0
      end
    end

    def parse_goals(value)
      case value
      when Integer then value.to_f
      when /^\d+$/ then value.to_i.to_f
      when /^more\s*(\d+)$/i then $1.to_i + MORE_GOALS_OFFSET
      end
    end
  end
end
