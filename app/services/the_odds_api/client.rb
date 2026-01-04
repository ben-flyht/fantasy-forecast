require "net/http"
require "json"

module TheOddsApi
  class Client
    BASE_URL = "https://api.the-odds-api.com/v4"
    SPORT_KEY = "soccer_epl"
    DEFAULT_BOOKMAKER = "pinnacle"

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class RateLimitError < Error; end
    class QuotaExceededError < Error; end

    def initialize(api_key: nil)
      @api_key = api_key || ENV["THE_ODDS_API_KEY"]
      raise AuthenticationError, "THE_ODDS_API_KEY not configured" unless @api_key
    end

    def events
      get("/sports/#{SPORT_KEY}/events", {})
    end

    def odds(markets: %w[h2h spreads totals], bookmakers: [ DEFAULT_BOOKMAKER ])
      params = {
        regions: "eu,uk",
        markets: markets.join(","),
        bookmakers: bookmakers.join(","),
        oddsFormat: "decimal"
      }

      get("/sports/#{SPORT_KEY}/odds", params)
    end

    def event_odds(event_id:, markets: %w[team_totals alternate_totals], bookmakers: [ DEFAULT_BOOKMAKER ])
      params = {
        regions: "eu,uk",
        markets: markets.join(","),
        bookmakers: bookmakers.join(","),
        oddsFormat: "decimal"
      }

      get("/sports/#{SPORT_KEY}/events/#{event_id}/odds", params)
    end

    def remaining_requests
      @remaining_requests
    end

    def used_requests
      @used_requests
    end

    private

    def get(endpoint, params)
      uri = build_uri(endpoint, params)
      response = make_request(uri)
      handle_response(response)
    end

    def build_uri(endpoint, params)
      uri = URI("#{BASE_URL}#{endpoint}")
      params_with_key = params.merge(apiKey: @api_key)
      uri.query = URI.encode_www_form(params_with_key)
      uri
    end

    def make_request(uri)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
    end

    def handle_response(response)
      track_quota(response)

      case response.code.to_i
      when 200 then JSON.parse(response.body)
      when 401 then raise AuthenticationError, "Invalid API key"
      when 422 then raise Error, parse_error_message(response)
      when 429 then raise RateLimitError, "Rate limit exceeded"
      else raise Error, "API request failed: #{response.code} - #{response.body}"
      end
    end

    def track_quota(response)
      @remaining_requests = response["x-requests-remaining"]&.to_i
      @used_requests = response["x-requests-used"]&.to_i
    end

    def parse_error_message(response)
      data = JSON.parse(response.body)
      data["message"] || "Validation error"
    rescue JSON::ParserError
      response.body
    end
  end
end
