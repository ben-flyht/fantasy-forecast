module Fpl
  # Detects the start of a new FPL season by comparing the set of team `code`s
  # in the API against what we have stored. Team codes are stable for a club
  # across its whole history and never change mid-season, but ~3 change every
  # summer through promotion/relegation, so a difference is a reliable signal.
  class NewSeasonDetector < ApplicationService
    EXPECTED_TEAM_COUNT = 20

    def initialize(api: Api.new)
      @api = api
    end

    def call
      api_codes = fetch_team_codes
      return false unless api_codes # unreachable or garbage response: never claim a new season

      new_season?(api_codes)
    end

    private

    def new_season?(api_codes)
      stored = Team.pluck(:code).compact.to_set
      return false if stored.empty?                   # first ever sync: nothing to reset
      return false if api_codes.size < EXPECTED_TEAM_COUNT # partial response: don't risk a false wipe

      api_codes.to_set != stored
    end

    def fetch_team_codes
      data = @api.bootstrap
      return nil unless data

      (data["teams"] || []).filter_map { |team| team["code"] }.presence
    end
  end
end
