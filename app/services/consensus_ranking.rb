class ConsensusRanking
  BASE_VOTE_WEIGHT = 1.0

  Ranking = Struct.new(
    :player_id, :name, :first_name, :last_name, :team, :team_id,
    :position, :bot_rank, :human_votes, :weighted_votes, :consensus_score,
    :tier, :tier_symbol, :tier_name,
    keyword_init: true
  )

  def self.for_week_and_position(gameweek, position = nil, team_id = nil)
    new(gameweek, position, team_id).rankings
  end

  def self.forecasters_beating_bot
    BotBeaters.new.call
  end

  def initialize(gameweek, position = nil, team_id = nil)
    @gameweek = gameweek
    @position = position
    @team_id = team_id
  end

  def rankings
    return [] unless bot && gameweek_record

    build_rankings
  end

  private

  def bot
    @bot ||= User.bot rescue nil
  end

  def gameweek_record
    @gameweek_record ||= Gameweek.find_by(fpl_id: @gameweek)
  end

  def build_rankings
    ranked, unranked = bot_forecasts.partition { |f| f.rank.present? }
    build_ranked_results(ranked) + build_unranked_results(unranked)
  end

  def build_ranked_results(forecasts)
    forecasts.map { |f| build_ranking(f) }.sort_by { |r| [ -r.consensus_score, r.name ] }
  end

  def build_unranked_results(forecasts)
    forecasts.map { |f| build_ranking(f) }.sort_by { |r| r.name.downcase }
  end

  def bot_forecasts
    forecasts = bot.forecasts.includes(player: :team).where(gameweek: gameweek_record)
    forecasts = forecasts.joins(:player).where(players: { position: @position }) if @position.present?
    forecasts = forecasts.joins(:player).where(players: { team_id: @team_id }) if @team_id.present?
    forecasts
  end

  def build_ranking(forecast)
    player = forecast.player
    weighted = weighted_votes_by_player[player.id]

    Ranking.new(
      **player_attributes(player),
      bot_rank: forecast.rank,
      human_votes: vote_count_by_player[player.id],
      weighted_votes: weighted.round(2),
      consensus_score: forecast.rank ? weighted - forecast.rank : nil
    )
  end

  def player_attributes(player)
    { player_id: player.id, name: player.short_name, first_name: player.first_name,
      last_name: player.last_name, team: player.team&.short_name || "???",
      team_id: player.team_id, position: player.position }
  end

  def weighted_votes_by_player
    @weighted_votes_by_player ||= calculate_weighted_votes[:weighted]
  end

  def vote_count_by_player
    @vote_count_by_player ||= calculate_weighted_votes[:counts]
  end

  def calculate_weighted_votes
    weighted = Hash.new(0.0)
    counts = Hash.new(0)

    human_forecasts.each do |player_id, user_id|
      weight = vote_weights[user_id] || 0.0
      weighted[player_id] += weight
      counts[player_id] += 1
    end

    @weighted_votes_by_player = weighted
    @vote_count_by_player = counts
    { weighted: weighted, counts: counts }
  end

  def human_forecasts
    Forecast.joins(:user)
            .where(gameweek: gameweek_record, users: { bot: false }, user_id: vote_weights.keys)
            .pluck(:player_id, :user_id)
  end

  def vote_weights
    @vote_weights ||= VoteWeightCalculator.new.call
  end

  # Inner class for vote weight calculation
  class VoteWeightCalculator
    def call
      return {} if bot_accuracy == 0.0

      overall_rankings.select { |r| r[:beats_bot] }.each_with_object({}) do |r, weights|
        weights[r[:user_id]] = (r[:accuracy_score] / bot_accuracy) * BASE_VOTE_WEIGHT
      end
    end

    private

    def overall_rankings
      @overall_rankings ||= ForecasterRankings.overall
    end

    def bot_accuracy
      @bot_accuracy ||= overall_rankings.find { |r| r[:is_bot] }&.dig(:accuracy_score) || 0.0
    end
  end

  # Inner class for forecasters beating bot
  class BotBeaters
    def call
      return [] if bot_accuracy == 0.0

      overall_rankings.select { |r| r[:beats_bot] }.map { |r| build_result(r) }
    end

    private

    def overall_rankings
      @overall_rankings ||= ForecasterRankings.overall
    end

    def bot_accuracy
      @bot_accuracy ||= overall_rankings.find { |r| r[:is_bot] }&.dig(:accuracy_score) || 0.0
    end

    def build_result(ranking)
      weight = (ranking[:accuracy_score] / bot_accuracy) * BASE_VOTE_WEIGHT
      { user_id: ranking[:user_id], username: ranking[:username],
        accuracy_score: ranking[:accuracy_score], vote_weight: weight.round(3) }
    end
  end
end
