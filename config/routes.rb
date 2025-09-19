Rails.application.routes.draw do
  resources :predictions do
    collection do
      post :sync_all
      patch :update_prediction
    end
  end
  resources :players
  devise_for :users
  root "home#index"

  # Consensus routes
  get "/consensus", to: "consensus#index", as: :consensus_index
  get "/consensus/weekly(/:week)", to: "consensus#weekly", as: :consensus_weekly

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
