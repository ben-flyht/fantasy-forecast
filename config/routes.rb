Rails.application.routes.draw do
  # The front page introduces the three things this site does and shows a little of
  # each, so somebody arriving from a search meets answers rather than a menu.
  root "home#show"

  # The rankings in full, with every filter. They used to be the front page, which
  # left nowhere to say what the site was for.
  get "rankings", to: "players#index", as: :rankings

  POSITIONS = /goalkeepers|defenders|midfielders|forwards/

  # SEO-friendly forecast URLs. Two horizons: all the football that remains, or
  # one week of it.
  get "season/:position", to: "players#index", as: :season_position,
      defaults: { horizon: "season" }, constraints: { position: POSITIONS }

  get "gameweeks/:gameweek/:position", to: "players#index", as: :gameweek_position,
      constraints: { gameweek: /\d+/, position: POSITIONS }

  # The run of fixtures a transfer is actually made over. No number in the address:
  # how far it looks is Horizon::WINDOW's business, and moving it should not move the
  # page.
  get "upcoming/:position", to: "players#index", as: :upcoming_position,
      defaults: { horizon: "upcoming" }, constraints: { position: POSITIONS }

  # The season used to be spelled as though it were a gameweek.
  get "gameweeks/ros/:position", to: redirect("/season/%{position}", status: 301),
      constraints: { position: POSITIONS }

  # The armband, which is the one decision every manager makes every single week.
  # No horizon: you captain a player for a gameweek or you do not captain him.
  get "captain", to: "captains#show", as: :captain

  # Him or him: the question a manager asks when he has already narrowed it to
  # two, with an address of its own so it can be found by asking it.
  # Two player addresses and a separator, and no dots: a card asked for as .png
  # stays a card rather than becoming a third player.
  PAIR = /[a-z0-9\-]+-vs-[a-z0-9\-]+/

  get "compare", to: "comparisons#index", as: :comparisons

  # Who you might mean, from the few letters you have typed. Declared before the pair
  # so it is never mistaken for one, though the constraint below would refuse it
  # anyway: a pair has "-vs-" in it and this does not.
  get "compare/search", to: "comparisons#search", as: :comparison_search

  get "compare/:pair", to: "comparisons#show", as: :comparison, constraints: { pair: PAIR }

  # Redirect old /players path to root
  get "players", to: redirect("/", status: 301)

  # Player detail page
  resources :players, only: [ :show ]

  # The best fifteen £100.0m buys. Two horizons, the same as the rankings.
  #
  # The squad, because that is what it is: fifteen players, not eleven, and not a
  # recommendation to play a chip. It was called the wildcard, which told managers to
  # spend something we were not advising them to spend, and it was called the best XI,
  # which is not what fifteen players are.
  get "squad", to: "squads#show", as: :squad, defaults: { horizon: "gameweek" }
  get "squad/upcoming", to: "squads#show", as: :upcoming_squad, defaults: { horizon: "upcoming" }
  get "squad/season", to: "squads#show", as: :season_squad, defaults: { horizon: "season" }

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
