require "net/http"
require "json"

module ApiFootball
  class Client
    BASE_URL = "https://v3.football.api-sports.io"
    PREMIER_LEAGUE_ID = 39

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class RateLimitError < Error; end

    def initialize(api_key: nil)
      @api_key = api_key || ENV["API_FOOTBALL_API_KEY"] || ENV["API_FOOTBALL_KEY"]
      raise AuthenticationError, "API_FOOTBALL_API_KEY not configured" unless @api_key
    end

    def fixtures(league_id: PREMIER_LEAGUE_ID, season:, from: nil, to: nil)
      params = { league: league_id, season: season }
      params[:from] = from.to_date.iso8601 if from
      params[:to] = to.to_date.iso8601 if to

      get("/fixtures", params)
    end

    def odds(fixture_id:, bet_id: nil)
      params = { fixture: fixture_id }
      params[:bet] = bet_id if bet_id

      get("/odds", params)
    end

    def teams(league_id: PREMIER_LEAGUE_ID, season:)
      get("/teams", { league: league_id, season: season })
    end

    def status
      get("/status", {})
    end

    private

    def get(endpoint, params)
      uri = build_uri(endpoint, params)
      response = make_request(uri)
      handle_response(response)
    end

    def build_uri(endpoint, params)
      uri = URI("#{BASE_URL}#{endpoint}")
      uri.query = URI.encode_www_form(params) unless params.empty?
      uri
    end

    def make_request(uri)
      request = Net::HTTP::Get.new(uri)
      request["x-apisports-key"] = @api_key

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    end

    def handle_response(response)
      case response.code.to_i
      when 200 then parse_successful_response(response)
      when 401, 403 then raise AuthenticationError, "Invalid API key"
      when 429 then raise RateLimitError, "Rate limit exceeded"
      else raise Error, "API request failed: #{response.code} - #{response.body}"
      end
    end

    def parse_successful_response(response)
      data = JSON.parse(response.body)
      check_for_errors(data)
      data["response"]
    end

    def check_for_errors(data)
      errors = data["errors"]
      return if errors.nil? || errors.empty?
      return unless errors.is_a?(Hash)

      raise_appropriate_error(errors)
    end

    def raise_appropriate_error(errors)
      raise AuthenticationError, errors["token"] if errors["token"]
      raise Error, errors["plan"] if errors["plan"]
      raise Error, errors.values.join(", ")
    end
  end
end
