module PackManager
  extend ActiveSupport::Concern

  included do
    helper_method :current_manager
  end

  private

  def current_manager
    @current_manager ||= Manager.find_by(id: session[:manager_id]) if session[:manager_id]
  end

  def sign_in_manager(manager)
    reset_session
    session[:manager_id] = manager.id
  end

  def require_manager
    redirect_to pack_landing_path unless current_manager
  end
end
