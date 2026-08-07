# The front page: what this site does, and enough of each answer to be worth reading
# on its own.
#
# It is not a menu. A page that only points at other pages gives a search engine
# nothing to rank and a reader nothing to take away, so the best players, the
# squad and the arguments worth having are all on it, in the markup, from
# the same stored forecast every other page is read from.
class HomeController < ApplicationController
  # Five: enough to be an answer rather than a taste, few enough that the page stays
  # an introduction to four things rather than a ranking with three footnotes.
  SHORTLIST = 5
  ARGUMENTS_PER_POSITION = 2
  HORIZON = "gameweek".freeze

  def show
    @gameweek = Gameweek.next_gameweek
    load_shortlist
    @squad = Squad.find_by(gameweek: @gameweek, horizon: HORIZON)
    @arguments = best_arguments
  end

  private

  # A couple from each position rather than all of one, so the front page does not
  # read as a page about forwards.
  def best_arguments
    PopularComparisons.call(gameweek: @gameweek, horizon: HORIZON)
                      .values.flat_map { |pairs| pairs.first(ARGUMENTS_PER_POSITION) }
  end

  # The best few players in the game, whatever they play. A taste rather than a list:
  # the rankings themselves are one click away and this page has two other things to
  # say.
  #
  # Ordered by the score itself rather than by a forecast's rank, because a rank is
  # a player's place within his own position: taking the first few of those would
  # return four number ones and nobody else.
  def load_shortlist
    @shortlist = TierCalculator.call(best_few)
    @shortlist.each_with_index { |ranking, place| ranking.bot_rank = place + 1 }
    @players = Player.includes(:team).where(id: @shortlist.map(&:player_id)).index_by(&:id)
    @costs = Statistic.where(type: "now_cost").latest_by_player
  end

  def best_few
    ConsensusRanking.call(@gameweek&.fpl_id, nil, nil, horizon: HORIZON)
                    .select { |ranking| ranking.score.to_f.positive? }
                    .sort_by { |ranking| -ranking.score.to_f }
                    .first(SHORTLIST)
  end
end
