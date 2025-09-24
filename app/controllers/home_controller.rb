class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    # Always show the home page, regardless of authentication status
  end
end
