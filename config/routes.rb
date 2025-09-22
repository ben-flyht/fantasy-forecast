Rails.application.routes.draw do
  resources :forecasts do
    collection do
      post :sync_all
      patch :update_forecast
    end
  end
  devise_for :users
  root "home#index"

  # Consensus routes
  get "/consensus", to: "consensus#index", as: :consensus_index

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
