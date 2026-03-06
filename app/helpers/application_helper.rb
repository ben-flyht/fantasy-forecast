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

  def tier_info(tier)
    TierCalculator::TIERS[tier]
  end

  DRAFT_STYLES = {
    mine: {
      background: "bg-amber-50 hover:bg-amber-100/50",
      border: "border-amber-200 bg-amber-100",
      text: "text-amber-900"
    },
    opponent: {
      background: "bg-blue-50 hover:bg-blue-100/50",
      border: "border-blue-200 bg-blue-100",
      text: "text-blue-900"
    },
    owned: {
      background: "bg-zinc-100",
      border: "bg-zinc-100",
      text: "text-zinc-500"
    },
    default: {
      background: "hover:bg-zinc-50",
      border: "bg-zinc-100",
      text: "text-zinc-900"
    }
  }.freeze

  def draft_style(category, key)
    DRAFT_STYLES.fetch(category || :default, DRAFT_STYLES[:default])[key]
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
