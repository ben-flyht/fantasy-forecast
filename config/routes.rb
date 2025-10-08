Rails.application.routes.draw do
  devise_for :users

  root "pages#home"

  # Dynamic robots.txt based on environment
  get "robots.txt", to: "pages#robots", defaults: { format: "text" }

  # Legal pages with SEO-friendly URLs
  get "privacy-policy", to: "pages#privacy_policy", as: :privacy_policy
  get "terms-of-service", to: "pages#terms_of_service", as: :terms_of_service
  get "cookie-policy", to: "pages#cookie_policy", as: :cookie_policy
  get "contact-us", to: "pages#contact_us", as: :contact_us

  # Player rankings routes
  resources :players, only: [ :index ] do
    collection do
      post :toggle_forecast
    end
  end

  # Forecaster rankings routes
  resources :forecasters, only: [ :index, :show ] do
    member do
      get "gameweeks/:gameweek", to: "forecasters#gameweeks", as: "gameweeks"
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
