class WorkspaceController < ApplicationController
  before_action :disable_caching

  def show
    manifest = Rails.public_path.join("workspace-ui/.vite/manifest.json")
    @workspace_bundle = JSON.parse(manifest.read).fetch("src/main.jsx") if manifest.file?
  end

  def csrf
    render json: { csrf_token: form_authenticity_token }
  end

  private

  def disable_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
