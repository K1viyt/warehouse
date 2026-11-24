Rails.application.routes.draw do
  root "workspace#show"
  get "interface/csrf", to: "workspace#csrf"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "products" => "products#index"
  get "products/:id" => "products#show"
  get "products/:id/photo", to: "products#photo", as: :product_photo
  put "products/:id/photo", to: "products#update_photo"
  post "products" => "products#create"
  post "registrations" => "registrations#create"
  post "session" => "sessions#create"
  get "me" => "profiles#show"
  delete "session" => "sessions#destroy"
  get "registration_options", to: "registration_options#index"
  get "email_verification", to: "email_verifications#show", as: :email_verification
  post "email_verification", to: "email_verifications#create"
  post "email_verification/resend", to: "email_verifications#resend"
  post "/warehouses/:warehouse_id/stock_issues", to: "stock_movements#create"

  post "password_recovery", to: "password_recoveries#create"
  get "password_reset", to: "workspace#show", as: :password_reset
  post "password_reset", to: "passwords#reset"
  patch "password", to: "passwords#update"

  get "warehouses/:warehouse_id/inventory", to: "warehouse_operations#inventory"
  post "warehouses/:warehouse_id/journal/:id/reverse", to: "warehouse_operations#reverse"
  get "warehouses/:warehouse_id/journal", to: "warehouse_operations#journal"
  get "warehouses/:warehouse_id/documents", to: "warehouse_operations#index"
  post "warehouse_documents", to: "warehouse_operations#create"
  patch "warehouse_documents/:id", to: "warehouse_operations#update"
  patch "products/:id", to: "products#update"
  delete "products/:id", to: "products#destroy"
  post "products/:id/archive", to: "products#archive"

  namespace :admin do
    resources :password_recovery_requests, only: [ :index, :update, :destroy ]
    resources :warehouses, only: [ :index, :create, :update ]
    resources :warehouse_memberships, only: [ :index, :create, :update ]
    resources :access_events, only: :index
    get "users/pending", to: "users#pending"
    patch "users/:id/activate", to: "users#activate"
    patch "users/:id/block", to: "users#block"
    patch "users/:id/unblock", to: "users#unblock"
    get "users", to: "users#index"
  end
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
