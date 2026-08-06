require "net/http"
require "base64"

# A picture from somebody else's website, in the only form a card can use it.
#
# librsvg will not follow a link out of an SVG, and quite right too: it would make
# drawing a card a request to wherever the markup happened to point. So the bytes
# have to be inside the document, which means fetching them first.
#
# They are kept for a month because they do not change: a player's cutout is the
# same photograph all season, and the alternative is asking the Premier League for
# the same picture every time somebody shares a link.
class ShareCard::Image < ApplicationService
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 4

  KEEP = 1.month

  def initialize(url)
    @url = url
  end

  # A data URI, or nothing at all. A card missing a photograph is still a card;
  # a card that waited on a photograph is a link that never previewed.
  def call
    return if @url.blank?

    bytes = Rails.cache.fetch(cache_key, expires_in: KEEP) { fetch }
    return if bytes.blank?

    "data:image/png;base64,#{Base64.strict_encode64(bytes)}"
  end

  private

  def cache_key
    "share_card/image/#{Digest::MD5.hexdigest(@url)}"
  end

  def fetch
    response = get(URI(@url))
    response.body if response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.warn("Share card image #{@url} did not arrive: #{e.message}")
    nil
  end

  def get(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.get(uri.request_uri)
    end
  end
end
