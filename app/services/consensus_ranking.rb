class ConsensusRanking
  # Base weight for votes from users who beat the bot
  # Actual weight = BASE_VOTE_WEIGHT * (user_accuracy / bot_accuracy)
  BASE_VOTE_WEIGHT = 1.0

  Ranking = Struct.new(
    :player_id, :name, :first_name, :last_name, :team, :team_id,
    :position, :bot_rank, :human_votes, :weighted_votes, :consensus_score,
    keyword_init: true
  )

  def self.for_week_and_position(gameweek, position = nil, team_id = nil)
    new(gameweek, position, team_id).rankings
  end

  # Returns users who beat the bot's accuracy with their vote weight
  def self.forecasters_beating_bot
    overall = ForecasterRankings.overall
    bot_accuracy = overall.find { |r| r[:is_bot] }&.dig(:accuracy_score) || 0.0

    return [] if bot_accuracy == 0.0

    overall.select { |r| r[:beats_bot] }.map do |r|
      weight = (r[:accuracy_score] / bot_accuracy) * BASE_VOTE_WEIGHT
      {
        user_id: r[:user_id],
        username: r[:username],
        accuracy_score: r[:accuracy_score],
        vote_weight: weight.round(3)
      }
    end
  end

  def initialize(gameweek, position = nil, team_id = nil)
    @gameweek = gameweek
    @position = position
    @team_id = team_id
  end

  def rankings
    bot = User.bot rescue nil
    return [] unless bot

    gameweek_record = Gameweek.find_by(fpl_id: @gameweek)
    return [] unless gameweek_record

    # Get bot's ranked forecasts for this position
    bot_forecasts = bot.forecasts
                       .includes(player: :team)
                       .where(gameweek: gameweek_record)
                       .where.not(rank: nil)

    bot_forecasts = bot_forecasts.joins(:player).where(players: { position: @position }) if @position.present?
    bot_forecasts = bot_forecasts.joins(:player).where(players: { team_id: @team_id }) if @team_id.present?

    # Get vote weights for users who beat the bot
    vote_weights = calculate_vote_weights

    # Get human forecasts with user info (only from users who beat the bot)
    qualifying_user_ids = vote_weights.keys
    human_forecasts = Forecast.joins(:user)
                              .where(gameweek: gameweek_record, users: { bot: false })
                              .where(user_id: qualifying_user_ids)
                              .pluck(:player_id, :user_id)

    # Calculate weighted votes per player
    weighted_votes_by_player = Hash.new(0.0)
    vote_count_by_player = Hash.new(0)

    human_forecasts.each do |player_id, user_id|
      weight = vote_weights[user_id] || 0.0
      weighted_votes_by_player[player_id] += weight
      vote_count_by_player[player_id] += 1
    end

    # Build rankings
    rankings = bot_forecasts.map do |forecast|
      player = forecast.player
      weighted_votes = weighted_votes_by_player[player.id]
      vote_count = vote_count_by_player[player.id]

      # Lower rank is better, weighted votes reduce the effective rank
      # consensus_score is inverted so higher = better for sorting
      effective_rank = forecast.rank - weighted_votes

      Ranking.new(
        player_id: player.id,
        name: player.short_name,
        first_name: player.first_name,
        last_name: player.last_name,
        team: player.team&.short_name || "???",
        team_id: player.team_id,
        position: player.position,
        bot_rank: forecast.rank,
        human_votes: vote_count,
        weighted_votes: weighted_votes.round(2),
        consensus_score: -effective_rank  # Negate so higher = better
      )
    end

    # Sort by consensus_score descending (higher is better)
    rankings.sort_by { |r| [ -r.consensus_score, r.name ] }
  end

  private

  def calculate_vote_weights
    overall = ForecasterRankings.overall
    bot_accuracy = overall.find { |r| r[:is_bot] }&.dig(:accuracy_score) || 0.0

    return {} if bot_accuracy == 0.0

    # Only users who beat the bot get voting power
    # Weight scales with how much they beat the bot
    overall.select { |r| r[:beats_bot] }.each_with_object({}) do |r, weights|
      weights[r[:user_id]] = (r[:accuracy_score] / bot_accuracy) * BASE_VOTE_WEIGHT
    end
  end
end
