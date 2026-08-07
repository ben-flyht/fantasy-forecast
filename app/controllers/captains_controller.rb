# Who to captain, which is the one question every manager answers every week.
#
# The armband doubles a player's score, so the answer is not a new calculation: it
# is the highest forecast in the game for the coming gameweek, whatever he plays.
# Read from the same stored numbers as every other page, so it cannot disagree with
# the rankings.
class CaptainsController < ApplicationController
  # The pick, and the players close enough behind him to be worth arguing about.
  SHORTLIST = 6

  # A captain is a decision about one gameweek. There is no rest-of-season armband,
  # so unlike every other page here there is no horizon to choose.
  HORIZON = "gameweek".freeze

  # What we report about a candidate without rating him.
  FACT_TYPES = %w[now_cost selected_by_percent].freeze

  # Owned by fewer than this many managers and the armband is a differential: a week
  # that gains rank on the field rather than keeping pace with it.
  DIFFERENTIAL_OWNERSHIP = 10.0

  # How far down the list a differential is worth looking for. The six on show are
  # the six the whole game has already noticed, so a differential is almost never
  # among them: the point of the thing is a player the field has not backed.
  DIFFERENTIAL_POOL = 30

  def show
    @gameweek = Gameweek.next_gameweek
    load_candidates
    @pick = @candidates.first
    @differential = differential_pick
    @forecast_at = Forecast.where(gameweek: @gameweek, horizon: HORIZON).maximum(:updated_at)
  end

  private

  def load_candidates
    @pool = best_forecasts
    @candidates = TierCalculator.call(@pool.first(SHORTLIST))
    @candidates.each_with_index { |candidate, place| candidate.bot_rank = place + 1 }

    player_ids = @pool.map(&:player_id)
    @players = Player.includes(:team).where(id: player_ids).index_by(&:id)
    @facts = Statistic.where(player_id: player_ids, type: FACT_TYPES).latest_by_player
    @matches_by_team = @gameweek ? Match.by_team(@gameweek) : {}
  end

  # Ordered by the score itself rather than by a forecast's rank, because a rank is
  # a player's place within his own position: the first six of those would be four
  # number ones and two number twos.
  def best_forecasts
    ConsensusRanking.call(@gameweek&.fpl_id, nil, nil, horizon: HORIZON)
                    .select { |ranking| ranking.score.to_f.positive? }
                    .sort_by { |ranking| -ranking.score.to_f }
                    .first(DIFFERENTIAL_POOL)
  end

  # The best of the candidates the field has not already piled into. Never the pick
  # itself: if the outright answer is owned by nobody then there is no differential
  # to name, only the answer.
  #
  # A player we have no ownership reading for is not a differential. Not knowing how
  # many managers own him is not the same as knowing that few do, and naming him
  # would be claiming something we cannot show.
  def differential_pick
    @pool.drop(1).find do |candidate|
      ownership = ownership_of(candidate)
      ownership.present? && ownership < DIFFERENTIAL_OWNERSHIP
    end
  end

  def ownership_of(candidate)
    @facts.dig(candidate.player_id, "selected_by_percent")
  end
  helper_method :ownership_of
end
