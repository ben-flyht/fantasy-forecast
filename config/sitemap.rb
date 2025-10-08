# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://www.fantasyforecast.co.uk"
SitemapGenerator::Sitemap.create do
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: add(path, options={})
  #        (default options are used if you don't specify)
  #
  # Defaults: priority: 0.5, changefreq: 'weekly',
  #           lastmod: Time.now, host: default_host

  # Note: root path is added automatically by sitemap_generator

  # Static pages
  add privacy_policy_path, priority: 0.3, changefreq: "monthly"
  add terms_of_service_path, priority: 0.3, changefreq: "monthly"
  add cookie_policy_path, priority: 0.3, changefreq: "monthly"
  add contact_us_path, priority: 0.4, changefreq: "monthly"

  # Player rankings - main page with high priority
  add players_path, priority: 0.9, changefreq: "daily"

  # Player rankings by position (defaults to latest gameweek)
  positions = [ "forward", "midfielder", "defender", "goalkeeper" ]
  positions.each do |position|
    add players_path(position: position),
        priority: 0.9,
        changefreq: "daily"
  end

  # Forecaster rankings
  add forecasters_path, priority: 0.8, changefreq: "daily"

  # Top forecasters (first 50)
  User.joins(:forecasts)
      .group("users.id")
      .order("COUNT(forecasts.id) DESC")
      .limit(50)
      .each do |user|
    add forecaster_path(user), priority: 0.6, changefreq: "weekly"
  end
end
