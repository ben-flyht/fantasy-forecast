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
end
