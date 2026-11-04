class RegistrationOptionsController < ApplicationController
  def index
    organizations = Organization.includes(:warehouses)
    render json: organizations.as_json(only: [ :id, :name ],
    include: {
     warehouses: {
      only: [ :id, :name ]
    }
    }), status: :ok
  end
end
