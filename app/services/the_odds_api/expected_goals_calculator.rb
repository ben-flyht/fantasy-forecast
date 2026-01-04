module TheOddsApi
  class ExpectedGoalsCalculator < ApplicationService
    # Remove bookmaker margin (vig) - Pinnacle typically has ~2-3% margin
    ASSUMED_MARGIN = 0.025

    def initialize(event_data:, home_team:, away_team:)
      @event_data = event_data
      @home_team = home_team
      @away_team = away_team
    end

    def call
      bookmaker = find_pinnacle_bookmaker
      return nil unless bookmaker

      team_totals = find_market(bookmaker, "team_totals")
      alternate_totals = find_market(bookmaker, "alternate_totals")

      calculate_expected_goals(team_totals, alternate_totals)
    end

    private

    def find_pinnacle_bookmaker
      @event_data.dig("bookmakers")&.find { |b| b["key"] == "pinnacle" }
    end

    def find_market(bookmaker, key)
      bookmaker["markets"]&.find { |m| m["key"] == key }
    end

    def calculate_expected_goals(team_totals, alternate_totals)
      return calculate_from_team_totals(team_totals) if team_totals
      return calculate_from_alternate_totals(alternate_totals) if alternate_totals
      nil
    end

    def calculate_from_team_totals(market)
      outcomes = market["outcomes"]
      return nil unless outcomes&.any?

      home_xg = calculate_team_xg(outcomes, @home_team)
      away_xg = calculate_team_xg(outcomes, @away_team)
      return nil unless home_xg && away_xg

      build_team_totals_result(outcomes, home_xg, away_xg)
    end

    def build_team_totals_result(outcomes, home_xg, away_xg)
      {
        home_xg: home_xg.round(2),
        away_xg: away_xg.round(2),
        home_clean_sheet_probability: calculate_clean_sheet_probability(outcomes, @away_team),
        away_clean_sheet_probability: calculate_clean_sheet_probability(outcomes, @home_team)
      }
    end

    def calculate_team_xg(outcomes, team_name)
      team_outcomes = outcomes.select { |o| team_matches?(o["description"], team_name) }
      return nil if team_outcomes.empty?

      # Group by point (goal line)
      lines = group_by_line(team_outcomes)
      return nil if lines.empty?

      # Use the line with most data to estimate xG via Poisson
      best_line = lines.min_by { |point, _| (point - 1.5).abs }
      return nil unless best_line

      point, odds = best_line
      estimate_xg_from_line(point, odds)
    end

    def team_matches?(description, team_name)
      return false unless description
      normalize_team_name(description) == normalize_team_name(team_name)
    end

    def normalize_team_name(name)
      name.to_s.downcase.gsub(/\s+/, " ").strip
    end

    def group_by_line(outcomes)
      lines = {}
      outcomes.each do |outcome|
        point = outcome["point"]
        next unless point

        lines[point] ||= {}
        lines[point][outcome["name"].downcase] = outcome["price"]
      end
      lines.select { |_, odds| odds["over"] && odds["under"] }
    end

    def estimate_xg_from_line(point, odds)
      over_prob = implied_probability(odds["over"])
      under_prob = implied_probability(odds["under"])

      # Normalize to remove margin
      total = over_prob + under_prob
      over_prob /= total
      under_prob /= total

      # Use binary search to find lambda where P(X > point) = over_prob
      find_lambda_for_over_probability(point, over_prob)
    end

    def implied_probability(decimal_odds)
      return 0 if decimal_odds.nil? || decimal_odds <= 1
      1.0 / decimal_odds
    end

    def find_lambda_for_over_probability(point, target_over_prob)
      low, high = 0.1, 6.0
      20.times { low, high = binary_search_step(point, target_over_prob, low, high) }
      (low + high) / 2.0
    end

    def binary_search_step(point, target_over_prob, low, high)
      mid = (low + high) / 2.0
      current_over = 1.0 - poisson_cdf(point.floor, mid)
      current_over < target_over_prob ? [ mid, high ] : [ low, mid ]
    end

    def poisson_cdf(k, lambda)
      return 0 if lambda <= 0
      sum = 0.0
      (0..k).each do |i|
        sum += poisson_pmf(i, lambda)
      end
      sum
    end

    def poisson_pmf(k, lambda)
      return 0 if lambda <= 0
      (lambda**k * Math.exp(-lambda)) / factorial(k)
    end

    def factorial(n)
      return 1 if n <= 1
      (1..n).reduce(:*)
    end

    def calculate_clean_sheet_probability(outcomes, opponent_team)
      # Find opponent's Under 0.5 line (opponent scores 0 = our clean sheet)
      opponent_outcomes = outcomes.select { |o| team_matches?(o["description"], opponent_team) }

      under_05 = opponent_outcomes.find { |o| o["name"] == "Under" && o["point"] == 0.5 }
      return nil unless under_05

      # Implied probability with margin removed
      raw_prob = implied_probability(under_05["price"])
      (raw_prob * (1 + ASSUMED_MARGIN)).clamp(0, 1).round(3)
    end

    def calculate_from_alternate_totals(market)
      # Fallback: estimate total goals from alternate_totals, split evenly
      outcomes = market["outcomes"]
      return nil unless outcomes&.any?

      total_xg = estimate_total_xg(outcomes)
      return nil unless total_xg

      # Without team-specific data, split based on home advantage (~55/45)
      {
        home_xg: (total_xg * 0.55).round(2),
        away_xg: (total_xg * 0.45).round(2),
        home_clean_sheet_probability: nil,
        away_clean_sheet_probability: nil
      }
    end

    def estimate_total_xg(outcomes)
      over_25, under_25 = find_25_line_outcomes(outcomes)
      return nil unless over_25 && under_25

      over_prob = normalize_probability(over_25["price"], under_25["price"])
      find_lambda_for_over_probability(2.5, over_prob)
    end

    def find_25_line_outcomes(outcomes)
      over = outcomes.find { |o| o["name"] == "Over" && o["point"] == 2.5 }
      under = outcomes.find { |o| o["name"] == "Under" && o["point"] == 2.5 }
      [ over, under ]
    end

    def normalize_probability(over_price, under_price)
      over_prob = implied_probability(over_price)
      under_prob = implied_probability(under_price)
      over_prob / (over_prob + under_prob)
    end
  end
end
