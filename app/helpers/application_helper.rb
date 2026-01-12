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

  def player_structured_data(player)
    schema = player_schema(player)
    tag.script(schema.to_json.html_safe, type: "application/ld+json")
  end

  def tier_badge_classes(tier)
    {
      1 => "bg-amber-400/20 text-amber-700",
      2 => "bg-lime-400/20 text-lime-700",
      3 => "bg-zinc-600/10 text-zinc-700",
      4 => "bg-sky-400/20 text-sky-700",
      5 => "bg-blue-400/20 text-blue-700"
    }[tier] || "bg-zinc-600/10 text-zinc-700"
  end

  def tier_info(tier)
    TierCalculator::TIERS[tier]
  end

  def cached_news_count(player)
    GoogleNews::FetchPlayerNews.cached_count(player)
  end

  def forecast_tier_background(tier_name)
    {
      "Sunshine" => "bg-amber-100",
      "Partly Cloudy" => "bg-amber-50",
      "Cloudy" => "bg-gray-100",
      "Rainy" => "bg-blue-50",
      "Snow" => "bg-blue-100"
    }[tier_name] || "bg-gray-50"
  end

  def performance_score_class(score)
    score_int = score.to_i
    if score_int >= 10
      "text-lime-700"
    elsif score_int <= 2
      "text-red-700"
    else
      "text-zinc-950"
    end
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

  def player_schema(player)
    schema = {
      "@context": "https://schema.org",
      "@type": "Person",
      "name": player.full_name,
      "url": "#{BASE_URL}#{player_path(player)}",
      "jobTitle": "Professional Football Player",
      "description": "#{player.full_name} - #{player.position.capitalize} for #{player.team&.name || 'Premier League'}"
    }
    schema[:affiliation] = { "@type": "SportsTeam", "name": player.team.name } if player.team.present?
    schema
  end
end
