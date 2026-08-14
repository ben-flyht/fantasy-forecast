# The arguments worth putting on a page.
#
# Every pair of players has an address, which is a hundred and sixty thousand
# addresses, and nobody is arguing about most of them. The ones people argue about
# are the ones next to each other near the top of a position: if our forecast can
# barely separate two players, that is exactly the pick somebody is stuck on.
#
# So the pairs are consecutive ranks, best first. It gives the crawler a way in and
# the reader a page that is about something.
class PopularComparisons < ApplicationService
  # How far down a position an argument is still worth having. Past this the two
  # players in a pair are ones nobody is choosing between.
  DEPTH = 12

  POSITIONS = %w[forward midfielder defender goalkeeper].freeze

  def initialize(gameweek:, horizon: "gameweek")
    @gameweek = gameweek
    @horizon = horizon
  end

  # Pairs by position, in the order a reader would want to scan them.
  def call
    return {} unless @gameweek

    POSITIONS.index_with { |position| pairs_for(position) }.reject { |_, pairs| pairs.empty? }
  end

  private

  def pairs_for(position)
    ranked.fetch(position, []).each_cons(2).map { |left, right| Matchup.new(left, right) }
  end

  # The best of each position for the week on show, best first. Ranks are counted
  # within a position, so one reading of the top dozen answers all four.
  def ranked
    @ranked ||= Forecast.where(gameweek: @gameweek, horizon: @horizon, rank: 1..DEPTH)
                        .includes(player: :team)
                        .order(:rank)
                        .map(&:player)
                        .group_by(&:position)
  end
end
