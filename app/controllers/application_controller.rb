class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def robots
    @app_host = ENV.fetch("APP_HOST", "www.fantasyforecast.co.uk")
    @is_production = @app_host.include?("www.fantasyforecast.co.uk")
    render "shared/robots", formats: [ :text ]
  end

  def sitemap
    @base_url = "https://#{ENV.fetch('APP_HOST', 'www.fantasyforecast.co.uk')}"
    @players_by_position = Player.select(:id, :position, :first_name, :last_name, :fpl_id).order(:position, :id).group_by(&:position)
    render "shared/sitemap", formats: [ :xml ]
  end
end
