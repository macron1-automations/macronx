Rails.application.routes.draw do
  devise_for :users

  authenticate :user, ->(u) { u.admin? } do
    mount Avo::Engine, at: "/avo"
  end

  resources :inboxes do
    collection do
      get :bulk_process_modal
      patch :bulk_process
      patch :bulk_archive
      delete :bulk_destroy
    end
    member do
      get  :process, action: :process_modal
      patch :process, action: :mark_processed
      patch :archive
    end
  end

  resources :workflows

  namespace :settings do
    resource :api_token, only: %i[show update]
  end

  namespace :api do
    namespace :v1 do
      resources :inboxes, only: %i[index show create]
    end
  end

  root "dashboards#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
