require "net/http"

module History
  class Download < ApplicationService
    VAASTAV = "https://raw.githubusercontent.com/vaastav/Fantasy-Premier-League/master/data/%<season>s/%<file>s".freeze
    VAASTAV_FILES = %w[gws/merged_gw.csv players_raw.csv fixtures.csv teams.csv].freeze
    FOOTBALL_DATA = "https://www.football-data.co.uk/mmz4281/%<code>s/E0.csv".freeze
    REDIRECTS = 3

    def initialize(dir)
      @dir = dir
    end

    def call
      vaastav + football_data
    end

    private

    def vaastav
      seasons.flat_map do |season|
        VAASTAV_FILES.map do |file|
          save(format(VAASTAV, season: season, file: file), File.join(Report.season_dir(@dir, season), File.basename(file)))
        end
      end
    end

    def football_data
      Report::SEASONS.keys.map do |season|
        save(format(FOOTBALL_DATA, code: Report::SEASONS.dig(season, :odds)), Report.odds_file(@dir, season))
      end
    end

    def seasons
      (Report::SEASONS.keys + Report::SEASONS.values.map { |sources| sources[:previous] }).uniq.sort
    end

    def save(url, path)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, fetch(URI(url)))
      path
    end

    def fetch(uri, redirects = REDIRECTS)
      response = Net::HTTP.get_response(uri)
      return response.body if response.is_a?(Net::HTTPSuccess)
      raise "#{uri} answered #{response.code}" unless response.is_a?(Net::HTTPRedirection) && redirects.positive?

      fetch(uri.merge(response["location"]), redirects - 1)
    end
  end
end
