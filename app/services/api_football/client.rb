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
      uri = URI("#{BASE_URL}#{endpoint}")
      uri.query = URI.encode_www_form(params) unless params.empty?

      request = Net::HTTP::Get.new(uri)
      request["x-apisports-key"] = @api_key

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      handle_response(response)
    end

    def handle_response(response)
      case response.code.to_i
      when 200
        data = JSON.parse(response.body)
        check_for_errors(data)
        data["response"]
      when 401, 403
        raise AuthenticationError, "Invalid API key"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      else
        raise Error, "API request failed: #{response.code} - #{response.body}"
      end
    end

    def check_for_errors(data)
      errors = data["errors"]
      return if errors.nil? || errors.empty?

      if errors.is_a?(Hash)
        if errors["token"]
          raise AuthenticationError, errors["token"]
        elsif errors["plan"]
          raise Error, errors["plan"]
        else
          raise Error, errors.values.join(", ")
        end
      end
    end
  end
end
