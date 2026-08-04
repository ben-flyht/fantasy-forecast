require "net/http"
require "json"

module Fpl
  # One conversation with FPL, however many syncs join in.
  #
  # The hourly run used to ask for the same bootstrap four times and the same
  # fixture list twice, through five hand-rolled requests that each had their own
  # idea of who we are and no idea when to give up waiting. Handed the same Api,
  # the syncs ask once and all read the same publication, so an update landing
  # mid-run cannot leave players and payloads describing different afternoons.
  #
  # An Api is a single run's worth of answers. Keeping one longer would be a cache,
  # which is a different thing wanting a different conversation about staleness.
  class Api
    BASE = "https://fantasy.premierleague.com/api/".freeze
    BOOTSTRAP_URL = "#{BASE}bootstrap-static/".freeze
    FIXTURES_URL = "#{BASE}fixtures/".freeze

    USER_AGENT = "Fantasy Forecast App".freeze

    # FPL is somebody else's website and we are a scheduled job: wait a moment,
    # then get on with the rest of the run. The next hour is the retry.
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    def initialize
      @answers = {}
    end

    def bootstrap
      once(BOOTSTRAP_URL)
    end

    def fixtures
      once(FIXTURES_URL)
    end

    def live(gameweek_fpl_id)
      fetch("#{BASE}event/#{gameweek_fpl_id}/live/")
    end

    def summary(player_fpl_id)
      fetch("#{BASE}element-summary/#{player_fpl_id}/")
    end

    private

    # Asked once, answered once, including when the answer was nothing: an
    # endpoint that is down must not be waited on four times over.
    #
    # Only the publications a run asks for more than once are kept. A player's
    # summary is read once and then finished with, and there are seven hundred of
    # them: held onto, they would be the largest thing on the dyno.
    def once(url)
      @answers.fetch(url) { @answers[url] = fetch(url) }
    end

    def fetch(url)
      response = request(URI(url))
      return log_refusal(url, response) unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue => e
      Rails.logger.error "FPL request to #{url} failed: #{e.message}"
      nil
    end

    def request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT
        http.request(request)
      end
    end

    def log_refusal(url, response)
      Rails.logger.error "FPL returned #{response.code} for #{url}"
      nil
    end
  end
end
