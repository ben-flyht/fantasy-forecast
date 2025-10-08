class PagesController < ApplicationController
  skip_before_action :authenticate_user!

  def home
  end

  def privacy_policy
  end

  def terms_of_service
  end

  def cookie_policy
  end

  def contact_us
  end

  def robots
    # Only allow indexing on production domain
    is_production = ENV.fetch("APP_HOST", "").include?("www.fantasyforecast.co.uk")

    respond_to do |format|
      format.text do
        if is_production
          render plain: <<~ROBOTS
            # Allow all crawlers on production
            User-agent: *
            Allow: /

            # Sitemap location
            Sitemap: https://www.fantasyforecast.co.uk/sitemap.xml.gz
          ROBOTS
        else
          render plain: <<~ROBOTS
            # Disallow all crawlers on non-production environments
            User-agent: *
            Disallow: /
          ROBOTS
        end
      end
    end
  end
end
