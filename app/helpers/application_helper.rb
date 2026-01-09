module ApplicationHelper
  BASE_URL = "https://www.fantasyforecast.co.uk"

  def meta_title
    content_for?(:meta_title) ? content_for(:meta_title) : "Fantasy Forecast - FPL Player Rankings"
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : "Weather-tiered FPL player rankings. Our algorithm analyzes form, fixtures, and expected goals to help you make better Fantasy Premier League decisions."
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
      1 => "bg-amber-100",      # ☀️ Sunshine - warm yellow
      2 => "bg-amber-50",        # 🌤️ Partly Cloudy - lighter yellow
      3 => "bg-gray-100",       # ☁️ Cloudy - gray
      4 => "bg-blue-50",         # 🌧️ Rainy - light blue
      5 => "bg-blue-100"          # ❄️ Snow - deeper blue
    }[tier] || ""
  end

  def tier_divide_class(_tier)
    "divide-y divide-white"
  end

  private

  def structured_data_schema
    { "@context": "https://schema.org", "@graph": [ website_schema, organization_schema ] }
  end

  def website_schema
    { "@type": "WebSite", "@id": "#{BASE_URL}/#website", "url": "#{BASE_URL}/",
      "name": "Fantasy Forecast",
      "description": "Weather-tiered FPL player rankings to help you make better Fantasy Premier League decisions" }
  end

  def organization_schema
    { "@type": "Organization", "@id": "#{BASE_URL}/#organization", "name": "Fantasy Forecast",
      "url": "#{BASE_URL}/", "logo": { "@type": "ImageObject", "url": "#{BASE_URL}/icon.png" }, "sameAs": [] }
  end
end
