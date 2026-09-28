class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def current_user
    User.find_by(id: session[:user_id])
  end
end
