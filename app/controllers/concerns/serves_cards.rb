# Serving the picture a page turns into when somebody shares it.
#
# A preview image is fetched by somebody else's server, long after the link was
# shared and usually more than once, so it is kept twice over: in front of us
# against the reading it was drawn from, and in their cache by an ordinary
# expiry header.
module ServesCards
  extend ActiveSupport::Concern

  # As often as the forecast behind a card is rewritten.
  CARD_LIFE = 1.hour

  private

  def send_card(template, key)
    expires_in CARD_LIFE, public: true
    send_data card(template, key), type: "image/png", disposition: "inline"
  end

  def card(template, key)
    Rails.cache.fetch(key, expires_in: CARD_LIFE) do
      ShareCard.call(render_to_string(template: template, formats: [ :svg ], layout: false))
    end
  end
end
