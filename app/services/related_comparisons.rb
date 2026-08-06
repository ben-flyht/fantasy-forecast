# The next argument, for a reader who has settled this one.
#
# Somebody weighing Salah against Palmer is usually weighing Salah against three
# other players too, so a comparison offers those instead of ending, and a
# player's own page offers the same. It is also how the rest of the pairs are
# found at all: every pair of players has an address, but an address nothing
# links to is one nobody will ever read.
#
# The candidates are the players ranked either side of the ones asked about,
# which is the rule the popular pairs are built from too: if our forecast can
# barely separate two players, that is exactly the pick somebody is stuck on.
class RelatedComparisons < ApplicationService
  # How far either side of a player to look. Two places up and two down is the
  # company he is actually being chosen among.
  SPREAD = 2

  def initialize(players:, gameweek:, horizon: "gameweek")
    @players = Array(players)
    @gameweek = gameweek
    @horizon = horizon
  end

  def call
    return [] unless @gameweek

    @players.flat_map { |player| pairs_for(player) }.uniq(&:slug)
  end

  private

  def pairs_for(player)
    neighbours(player).map { |other| Comparison.new(player, other) }
  end

  # Everyone ranked beside him, less the ones already on the page: offering the
  # same pair again, or a player against himself, is not another argument.
  def neighbours(player)
    rank = ranks[player.id]
    return [] unless rank

    ranked_near(player.position, rank).reject { |other| @players.include?(other) }
  end

  def ranked_near(position, rank)
    Forecast.joins(:player).includes(player: :team)
            .where(gameweek: @gameweek, horizon: @horizon)
            .where(players: { position: position })
            .where(rank: (rank - SPREAD)..(rank + SPREAD))
            .order(:rank)
            .map(&:player)
  end

  def ranks
    @ranks ||= Forecast.where(gameweek: @gameweek, horizon: @horizon, player: @players)
                       .pluck(:player_id, :rank).to_h
  end
end
