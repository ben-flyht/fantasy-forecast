module ApplicationHelper
  BASE_URL = "https://www.fantasyforecast.co.uk"

  def meta_title
    content_for?(:meta_title) ? content_for(:meta_title) : "Fantasy Forecast - FPL Player Rankings"
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : "FPL player rankings, graded. Our algorithm lets the market — price and ownership — lead, weighed against form, fixtures, and expected goals, to help you make better Fantasy Premier League decisions."
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : "#{BASE_URL}/icon.png?v=#{FantasyForecast::ICON_VERSION}"
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

  def tier_info(tier)
    TierCalculator::TIERS[tier]
  end

  # FPL holds prices in tenths of a million, so 155 reads as £15.5m.
  TENTHS_PER_MILLION = 10.0

  # What we report about a player without rating him: what he costs, and how much
  # of the field already owns him. Read them, judge them yourself.
  def player_facts(stats)
    [ player_price(stats&.dig("now_cost")), player_ownership(stats&.dig("selected_by_percent")) ].compact
  end

  def player_price(tenths)
    return if tenths.blank?

    format("£%.1fm", tenths.to_f / TENTHS_PER_MILLION)
  end

  def player_ownership(percent)
    return if percent.blank?

    format("%.1f%% owned", percent)
  end

  private

  def structured_data_schema
    { "@context": "https://schema.org", "@graph": [ website_schema, organization_schema ] }
  end

  def website_schema
    { "@type": "WebSite", "@id": "#{BASE_URL}/#website", "url": "#{BASE_URL}/",
      "name": "Fantasy Forecast",
      "description": "FPL player rankings, graded, to help you make better Fantasy Premier League decisions" }
  end

  def organization_schema
    { "@type": "Organization", "@id": "#{BASE_URL}/#organization", "name": "Fantasy Forecast",
      "url": "#{BASE_URL}/", "logo": { "@type": "ImageObject", "url": "#{BASE_URL}/icon.png?v=#{FantasyForecast::ICON_VERSION}" }, "sameAs": [] }
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
