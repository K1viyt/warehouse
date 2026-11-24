module Admin
  class AccessEventsController < ApplicationController
    before_action :require_active_user
    before_action :require_admin

    def index
      events = current_organization.access_events
      events = events.where(user_id: current_organization.users.find(params[:user_id]).id) if params[:user_id].present?
      if params[:before_id].present?
        cursor = current_organization.access_events.find(params[:before_id])
        events = events.where("(created_at, id) < (?, ?)", cursor.created_at, cursor.id)
      end
      rows = events.includes(:user, :actor).order(created_at: :desc, id: :desc).limit(51).to_a
      page = rows.first(50)
      render json: { events: page.map { |event|
        event.as_json(only: [ :id, :action, :details, :created_at, :user_id, :actor_id ])
          .merge(user_name: event.user.name, actor_name: event.actor.name)
      }, next_cursor: rows.size > 50 ? page.last.id : nil }
    end
  end
end
