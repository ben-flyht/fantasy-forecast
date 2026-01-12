Rails.application.routes.draw do
  root "players#index"

  # Redirect old /players path to root
  get "players", to: redirect("/", status: 301)

  # Player detail page
  resources :players, only: [:show]

  # Dynamic robots.txt based on environment
  get "robots.txt", to: "application#robots", defaults: { format: "text" }

  # Dynamic sitemap.xml
  get "sitemap.xml", to: "application#sitemap", defaults: { format: "xml" }

  # Legal pages with SEO-friendly URLs
  get "privacy-policy", to: "pages#privacy_policy", as: :privacy_policy
  get "terms-of-service", to: "pages#terms_of_service", as: :terms_of_service
  get "cookie-policy", to: "pages#cookie_policy", as: :cookie_policy
  get "contact-us", to: "pages#contact_us", as: :contact_us

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
