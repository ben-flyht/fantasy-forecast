require "net/http"
require "json"

module GoogleNews
  class Client
    BASE_URL = "https://www.googleapis.com/customsearch/v1"

    class Error < StandardError; end
    class AuthenticationError < Error; end
    class QuotaExceededError < Error; end

    def initialize(api_key: nil, cse_id: nil)
      @api_key = api_key || ENV["GOOGLE_API_KEY"]
      @cse_id = cse_id || ENV["GOOGLE_CSE_ID"]

      raise AuthenticationError, "GOOGLE_API_KEY not configured" unless @api_key
      raise AuthenticationError, "GOOGLE_CSE_ID not configured" unless @cse_id
    end

    def search(query, num: 5)
      params = {
        q: query,
        num: num,
        sort: "date:d",
        dateRestrict: "d7"
      }

      get(params)
    end

    private

    def get(params)
      uri = build_uri(params)
      response = make_request(uri)
      handle_response(response)
    end

    def build_uri(params)
      uri = URI(BASE_URL)
      params_with_auth = params.merge(key: @api_key, cx: @cse_id)
      uri.query = URI.encode_www_form(params_with_auth)
      uri
    end

    def make_request(uri)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
    end

    def handle_response(response)
      case response.code.to_i
      when 200 then parse_response(response)
      when 401, 403 then raise AuthenticationError, "Invalid API key or CSE ID"
      when 429 then raise QuotaExceededError, "Daily quota exceeded"
      else raise Error, "API request failed: #{response.code} - #{response.body}"
      end
    end

    def parse_response(response)
      data = JSON.parse(response.body, symbolize_names: true)
      data
    rescue JSON::ParserError => e
      raise Error, "Failed to parse response: #{e.message}"
    end
  end
end
