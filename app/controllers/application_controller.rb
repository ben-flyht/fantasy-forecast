class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  def robots
    @app_host = ENV.fetch("APP_HOST", "www.fantasyforecast.co.uk")
    @is_production = @app_host.include?("www.fantasyforecast.co.uk")
    render "shared/robots", formats: [ :text ]
  end

  def sitemap
    @base_url = "https://#{ENV.fetch('APP_HOST', 'www.fantasyforecast.co.uk')}"
    @players_by_position = Player.select(:id, :position, :first_name, :last_name, :fpl_id).order(:position, :id).group_by(&:position)
    gameweek = Gameweek.next_gameweek
    @next_gameweek = gameweek&.fpl_id
    @comparisons = sitemap_comparisons(gameweek)
    render "shared/sitemap", formats: [ :xml ]
  end

  private

  # The pairs our forecast puts closest together, and the pairs people have asked for
  # themselves, both worth a crawler's time. The asked-for ones lead: a page somebody
  # wanted is a better page to have found than one we guessed at. Groups are left out,
  # the same as they are on the page, which marks itself noindex.
  def sitemap_comparisons(gameweek)
    popular = PopularComparisons.call(gameweek: gameweek).values.flatten
    (MostRequestedComparisons.call(limit: 100) + popular).uniq(&:slug)
  end
end
