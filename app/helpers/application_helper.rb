module ApplicationHelper
  BASE_URL = "https://www.fantasyforecast.co.uk"

  # The four pages this site is. Everything else is reached from inside one of them,
  # so it belongs in the footer rather than here.
  NAVIGATION = [
    [ "Rankings", :rankings_path, "players" ],
    [ "Captain", :captain_path, "captains" ],
    [ "Squad", :squad_path, "squads" ],
    [ "Compare", :comparisons_path, "comparisons" ]
  ].freeze

  # Which one you are on is decided by the controller answering, not by the address,
  # because a ranking has an address per position and a gameweek and is one page.
  def navigation_links
    NAVIGATION.map do |label, path, on|
      [ label, public_send(path), controller.controller_name == on ]
    end
  end

  # Where a page goes back to when it has no parent of its own.
  #
  # Most people arrive on these pages cold, from a search, with no history to go back
  # through and nothing on screen saying what the rest of the site is. The nav row
  # says where else you could go; this says where to start.
  def back_home
    PageHeadingComponent::Back.new(label: "Back to Home", url: root_path)
  end

  def back_to(label, url)
    PageHeadingComponent::Back.new(label: "Back to #{label}", url: url)
  end

  # The two horizons every forecast is read at, in the shape the heading draws them.
  #
  # Named by the week rather than by "next": the title beside it already says which
  # gameweek this is, and "next" only means something to a reader who knows where in
  # the season he is standing.
  #
  # Links rather than a form, so both horizons are addresses a crawler can follow and
  # the toggle needs no JavaScript to work.
  def forecast_horizons(gameweek:, season:, gameweek_url:, season_url:)
    [
      PageHeadingComponent::Horizon.new(
        label: gameweek ? "Gameweek #{gameweek}" : "Next Gameweek",
        url: gameweek_url, current: !season
      ),
      PageHeadingComponent::Horizon.new(
        label: "Rest of Season", url: season_url, current: season
      )
    ]
  end

  def meta_title
    content_for?(:meta_title) ? content_for(:meta_title) : "Fantasy Forecast - FPL Player Rankings"
  end

  def meta_description
    content_for?(:meta_description) ? content_for(:meta_description) : "FPL player rankings, graded. Our algorithm lets the market — price and ownership — lead, weighed against form, fixtures, and expected goals, to help you make better Fantasy Premier League decisions."
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : "#{BASE_URL}/icon.png?v=#{FantasyForecast::ICON_VERSION}"
  end

  # A preview reserves the shape it is told to expect before the picture arrives, so a
  # card that is not the usual letterbox has to say so or it is laid out wrongly and
  # then jumps. Only the best XI is square; everything else is 1200 by 630.
  def meta_image_height
    content_for?(:meta_image_height) ? content_for(:meta_image_height) : ShareCard::HEIGHT
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

  # The questions a page answers, said again in the form a search engine reads. The
  # pairs are the same ones printed on the page: a schema that claims an answer the
  # reader cannot see is the one thing Google treats as a lie.
  def faq_structured_data(pairs)
    tag.script(faq_schema(pairs).to_json.html_safe, type: "application/ld+json")
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

  def faq_schema(pairs)
    { "@context": "https://schema.org", "@type": "FAQPage",
      "mainEntity": pairs.map { |question, answer|
        { "@type": "Question", "name": question,
          "acceptedAnswer": { "@type": "Answer", "text": strip_tags(answer).squish } }
      } }
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
