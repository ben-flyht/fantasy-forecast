module GoogleNews
  class FetchPlayerNews < ApplicationService
    CACHE_VERSION = "v1"
    CACHE_TTL = 6.hours

    def initialize(player:)
      @player = player
    end

    # Returns cached news count without making API call, or nil if not cached
    def self.cached_count(player)
      cache_key = "player_news/#{CACHE_VERSION}/player:#{player.id}"
      cached = Rails.cache.read(cache_key)
      cached&.size
    end

    def call
      # Return cached news if available
      cached = Rails.cache.read(cache_key)
      return cached if cached.present?

      # Only fetch from API if configured
      return [] unless api_configured?

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        fetch_news
      end
    end

    private

    def api_configured?
      ENV["GOOGLE_API_KEY"].present? && ENV["GOOGLE_CSE_ID"].present?
    end

    def cache_key
      "player_news/#{CACHE_VERSION}/player:#{@player.id}"
    end

    def fetch_news
      query = build_query
      response = client.search(query)
      normalize_articles(response[:items] || [])
    rescue GoogleNews::Client::Error => e
      Rails.logger.error("[GoogleNews] Failed to fetch news for #{@player.full_name}: #{e.message}")
      []
    end

    def build_query
      name_variants = [
        @player.full_name,
        @player.last_name,
        @player.short_name
      ].compact.uniq.map { |n| %("#{n}") }

      name_part = "(#{name_variants.join(' OR ')})"
      team_part = %("#{@player.team.name}") if @player.team.present?

      [name_part, team_part].compact.join(" ")
    end

    def client
      @client ||= GoogleNews::Client.new
    end

    def normalize_articles(items)
      items.map { |item| normalize_article(item) }
    end

    def normalize_article(item)
      {
        title: item[:title],
        snippet: item[:snippet],
        url: item[:link],
        image: item.dig(:pagemap, :cse_image, 0, :src),
        source: item[:displayLink]
      }
    end
  end
end
