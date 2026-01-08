module ApplicationHelper
  BASE_URL = "https://www.fantasyforecast.co.uk"

  def user_badge(user: nil, is_bot: nil, beats_bot: false)
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
    content_for?(:meta_title) ? content_for(:meta_title) : "Fantasy Forecast - Can You Beat the FPL Bot?"
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : "Challenge the most accurate FPL forecasting bot. Submit your player rankings each gameweek and see if you can beat the algorithm."
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : "#{BASE_URL}/icon.png"
  end

  def meta_url
    content_for?(:meta_url) ? content_for(:meta_url) : request.original_url
  end

  def structured_data
    tag.script(structured_data_schema.to_json.html_safe, type: "application/ld+json")
  end

  def tier_row_class(tier)
    {
      1 => "bg-amber-50",
      2 => "bg-sky-50",
      3 => "bg-gray-50",
      4 => "bg-slate-100",
      5 => "bg-blue-50"
    }[tier] || ""
  end

  private

  def structured_data_schema
    { "@context": "https://schema.org", "@graph": [ website_schema, organization_schema ] }
  end

  def website_schema
    { "@type": "WebSite", "@id": "#{BASE_URL}/#website", "url": "#{BASE_URL}/",
      "name": "Fantasy Forecast",
      "description": "Challenge the most accurate FPL forecasting bot and track your prediction accuracy" }
  end

  def organization_schema
    { "@type": "Organization", "@id": "#{BASE_URL}/#organization", "name": "Fantasy Forecast",
      "url": "#{BASE_URL}/", "logo": { "@type": "ImageObject", "url": "#{BASE_URL}/icon.png" }, "sameAs": [] }
  end
end
