require "mailgun-ruby"

# Configure Mailgun API client
Mailgun.configure do |config|
  config.api_key = ENV["MAILGUN_API_KEY"]
  config.domain = ENV["MAILGUN_DOMAIN"] || "fantasyforecast.co.uk"
  config.api_host = ENV["MAILGUN_API_HOST"] || "api.eu.mailgun.net"
end
