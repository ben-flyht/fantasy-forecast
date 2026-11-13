module PackSignIn
  extend ActiveSupport::Concern

  SIGNED_IN_FOR = 1.year

  included do
    helper_method :current_user
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session_user
  end

  def session_user
    id, token = cookies.signed[:play_session]
    user = User.find_by(id: id) if id
    user if user&.session_token && token && ActiveSupport::SecurityUtils.secure_compare(user.session_token, token.to_s)
  end

  def sign_in_user(user)
    cookies.signed[:play_session] = { value: [ user.id, user.session_token ], expires: SIGNED_IN_FOR,
                                      httponly: true, same_site: :lax, secure: Rails.env.production? }
  end

  def sign_out_user
    current_user&.regenerate_session_token
    cookies.delete(:play_session)
    cookies.delete(:user_id)
  end
end
