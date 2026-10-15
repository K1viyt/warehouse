class WorkspaceController < ApplicationController
  before_action :disable_caching

  def show
  end

  def csrf
    render json: { csrf_token: form_authenticity_token }
  end

  private

  def disable_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
