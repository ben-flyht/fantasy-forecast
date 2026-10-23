module PackManager
  extend ActiveSupport::Concern

  SIGNED_IN_FOR = 1.year
  PLAY_COOKIE = :play

  included do
    helper_method :current_manager
    before_action :remember_play
  end

  private

  def remember_play
    cookies.permanent[PLAY_COOKIE] = "1"
  end

  def current_manager
    return @current_manager if defined?(@current_manager)

    @current_manager = Manager.find_by(id: cookies.signed[:manager_id])
  end

  def sign_in_manager(manager)
    cookies.signed[:manager_id] = { value: manager.id, expires: SIGNED_IN_FOR, httponly: true, same_site: :lax }
  end

  def sign_out_manager
    cookies.delete(:manager_id)
  end
end
