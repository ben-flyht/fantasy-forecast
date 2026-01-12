module GoogleNews
  class FetchPlayerNews < ApplicationService
    CACHE_VERSION = "v2"
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
        @player.short_name,
        short_name_suffix
      ].compact.uniq.map { |n| %("#{n}") }

      name_part = "(#{name_variants.join(' OR ')})"
      team_part = %("#{@player.team.name}") if @player.team.present?

      [ name_part, team_part, @player.position ].compact.join(" ")
    end

    def short_name_suffix
      return nil unless @player.short_name&.include?(".")

      @player.short_name.split(".").last
    end

    def client
      @client ||= GoogleNews::Client.new
    end

    def normalize_articles(items)
      items
        .map { |item| normalize_article(item) }
        .sort_by { |article| article[:published_at] || Time.at(0) }
        .reverse
    end

    def normalize_article(item)
      {
        title: item[:title],
        snippet: clean_snippet(item[:snippet]),
        url: item[:link],
        source: item[:displayLink],
        image: item.dig(:pagemap, :cse_image, 0, :src),
        published_at: extract_published_date(item)
      }
    end

    def clean_snippet(snippet)
      return nil unless snippet.present?

      # Remove relative date prefix (e.g., "17 hours ago ... ")
      snippet.sub(/^\d+\s+(minute|hour|day|week|month)s?\s+ago\s*\.{0,3}\s*/i, "")
    end

    def extract_published_date(item)
      date_string = extract_date_from_metatags(item)
      return Time.parse(date_string) if date_string.present?

      # Try parsing relative date from snippet (e.g., "17 hours ago ...")
      parse_relative_date_from_snippet(item[:snippet])
    rescue ArgumentError, TypeError
      nil
    end

    def extract_date_from_metatags(item)
      metatags = item.dig(:pagemap, :metatags, 0) || {}
      metatags[:article_published_time] ||
        metatags[:"article:published_time"] ||
        metatags[:og_updated_time] ||
        metatags[:"og:updated_time"] ||
        metatags[:datepublished] ||
        metatags[:date]
    end

    def parse_relative_date_from_snippet(snippet)
      return nil unless snippet.present?
      return unless snippet.match?(%r{^(\d+)\s+(minute|hour|day|week|month)s?\s+ago}i)

      amount = Regexp.last_match(1).to_i
      unit = Regexp.last_match(2).downcase
      time_ago_from_unit(amount, unit)
    end

    def time_ago_from_unit(amount, unit)
      case unit
      when "minute" then amount.minutes.ago
      when "hour" then amount.hours.ago
      when "day" then amount.days.ago
      when "week" then amount.weeks.ago
      when "month" then amount.months.ago
      end
    end
  end
end
