module ApplicationHelper
  def user_badge(user: nil, is_bot: nil, beats_bot: false)
    # Support both User object and raw booleans
    if user
      badge = user.badge
      is_bot = user.bot?
    else
      badge = User.badge_for(bot: is_bot, beats_bot: beats_bot)
    end
    return nil unless badge

    title = is_bot ? "Bot forecaster" : "More accurate than the bot"
    tag.span(badge, title: title)
  end

  def meta_title
    content_for?(:meta_title) ? content_for(:meta_title) : "Fantasy Forecast - FPL Player Rankings & Consensus"
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : "Crowd-sourced Fantasy Premier League player rankings updated every gameweek. Make better FPL transfer and captain decisions with consensus rankings from experienced managers."
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : "https://www.fantasyforecast.co.uk/icon.png"
  end

  def meta_url
    content_for?(:meta_url) ? content_for(:meta_url) : request.original_url
  end

  def structured_data
    base_schema = {
      "@context": "https://schema.org",
      "@graph": [
        {
          "@type": "WebSite",
          "@id": "https://www.fantasyforecast.co.uk/#website",
          "url": "https://www.fantasyforecast.co.uk/",
          "name": "Fantasy Forecast",
          "description": "Crowd-sourced Fantasy Premier League player rankings updated every gameweek"
        },
        {
          "@type": "Organization",
          "@id": "https://www.fantasyforecast.co.uk/#organization",
          "name": "Fantasy Forecast",
          "url": "https://www.fantasyforecast.co.uk/",
          "logo": {
            "@type": "ImageObject",
            "url": "https://www.fantasyforecast.co.uk/icon.png"
          },
          "sameAs": []
        }
      ]
    }

    tag.script(base_schema.to_json.html_safe, type: "application/ld+json")
  end
end
