class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?

  def robots
    @app_host = ENV.fetch("APP_HOST", "www.fantasyforecast.co.uk")
    @is_production = @app_host.include?("www.fantasyforecast.co.uk")
    render "shared/robots", formats: [ :text ]
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end
end
