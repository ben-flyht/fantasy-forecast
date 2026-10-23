module PackSignIn
  extend ActiveSupport::Concern

  SIGNED_IN_FOR = 1.year
  PLAY_COOKIE = :play

  included do
    helper_method :current_user
    before_action :remember_play
  end

  private

  def remember_play
    cookies.permanent[PLAY_COOKIE] = "1"
  end

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: cookies.signed[:user_id])
  end

  def sign_in_user(user)
    cookies.signed[:user_id] = { value: user.id, expires: SIGNED_IN_FOR, httponly: true, same_site: :lax }
  end

  def sign_out_user
    cookies.delete(:user_id)
  end
end
