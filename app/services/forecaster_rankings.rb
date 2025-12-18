class ForecasterRankings
  def self.for_gameweek(gameweek)
    GameweekRankings.new(gameweek).call
  end

  def self.overall
    OverallRankings.new.call
  end

  def self.weekly_performance(user_id, limit: nil)
    WeeklyPerformance.new(user_id, limit: limit).call
  end

  def self.weekly_forecasts(user_id, gameweek_number)
    gameweek = Gameweek.find_by(fpl_id: gameweek_number)
    return [] unless gameweek

    user = User.find(user_id)
    forecasts = Forecast.includes(player: :team).where(user_id: user_id, gameweek: gameweek)
    forecasts = forecasts.where.not(accuracy: nil) if user.bot? && gameweek.is_finished?
    forecasts.order("accuracy DESC NULLS LAST")
  end

  # Inner class for gameweek rankings
  class GameweekRankings
    def initialize(gameweek)
      @gameweek = gameweek
      @gameweek_record = Gameweek.find_by(fpl_id: gameweek)
    end

    def call
      return [] unless @gameweek_record

      user_scores = calculate_user_scores
      add_ranks(user_scores)
    end

    private

    def calculate_user_scores
      all_forecasters.map { |user| build_user_score(user) }
    end

    def all_forecasters
      User.joins(:forecasts).where.not(forecasts: { accuracy: nil }).distinct.select(:id, :username, :bot)
    end

    def gameweek_scores
      @gameweek_scores ||= Forecast.joins(:user)
                                   .where(gameweek: @gameweek_record)
                                   .where.not(accuracy: nil)
                                   .select("forecasts.*", "users.username")
                                   .group_by(&:user_id)
    end

    def build_user_score(user)
      records = gameweek_scores[user.id] || []
      avg_accuracy = records.any? ? records.sum { |s| s.accuracy.to_f } / records.size : 0.0

      { user_id: user.id, username: user.display_name, accuracy_score: avg_accuracy.round(4), forecast_count: records.size }
    end

    def add_ranks(scores)
      scores.sort_by { |u| -u[:accuracy_score] }.each_with_index.map { |r, i| r.merge(rank: i + 1) }
    end
  end

  # Inner class for overall rankings
  class OverallRankings
    def initialize
      @starting_gameweek = Gameweek::STARTING_GAMEWEEK
    end

    def call
      return empty_rankings if gameweeks_with_scores.empty?

      user_scores = calculate_user_scores
      ranked_scores = add_ranks(user_scores)
      add_beats_bot(ranked_scores)
    end

    private

    def gameweeks_with_scores
      @gameweeks_with_scores ||= Forecast.joins(:gameweek)
                                         .where.not(accuracy: nil)
                                         .where("gameweeks.fpl_id >= ?", @starting_gameweek)
                                         .distinct
                                         .pluck("gameweeks.fpl_id")
    end

    def empty_rankings
      User.joins(:forecasts).distinct.select(:id, :username, :bot).order(:username).map do |user|
        { user_id: user.id, username: user.display_name, is_bot: user.bot?, accuracy_score: 0.0,
          forecast_count: 0, gameweeks_participated: 0, beats_bot: false, rank: "1=" }
      end
    end

    def calculate_user_scores
      all_forecasters.map { |user| build_user_score(user) }
    end

    def all_forecasters
      User.active.joins(forecasts: :gameweek)
          .where.not(forecasts: { accuracy: nil })
          .where("gameweeks.fpl_id >= ?", @starting_gameweek)
          .select(:id, :username, :bot)
    end

    def all_scores_by_user
      @all_scores_by_user ||= Forecast.joins(:gameweek, :user)
                                      .where.not(accuracy: nil)
                                      .where("gameweeks.fpl_id >= ?", @starting_gameweek)
                                      .select("forecasts.*", "gameweeks.fpl_id as gameweek_fpl_id")
                                      .group_by(&:user_id)
    end

    def build_user_score(user)
      user_scores_by_gw = (all_scores_by_user[user.id] || []).group_by(&:gameweek_fpl_id)
      stats = calculate_user_stats(user_scores_by_gw)

      { user_id: user.id, username: user.display_name, is_bot: user.bot?,
        accuracy_score: stats[:avg_accuracy].round(4), forecast_count: stats[:total_forecasts],
        gameweeks_participated: stats[:gameweeks_participated] }
    end

    def calculate_user_stats(user_scores_by_gw)
      stats = { accuracy_sum: 0.0, gameweeks: 0, forecasts: 0 }
      gameweeks_with_scores.each { |gw| accumulate_gameweek_stats(stats, user_scores_by_gw[gw]) }

      avg = stats[:gameweeks] > 0 ? stats[:accuracy_sum] / stats[:gameweeks] : 0.0
      { avg_accuracy: avg, gameweeks_participated: stats[:gameweeks], total_forecasts: stats[:forecasts] }
    end

    def accumulate_gameweek_stats(stats, forecasts)
      return unless forecasts&.any?

      stats[:accuracy_sum] += forecasts.sum { |f| f.accuracy.to_f } / forecasts.size
      stats[:gameweeks] += 1
      stats[:forecasts] += forecasts.size
    end

    def add_ranks(scores)
      scores.sort_by { |u| -u[:accuracy_score] }.each_with_index.map { |r, i| r.merge(rank: i + 1) }
    end

    def add_beats_bot(ranked_scores)
      bot_accuracy = ranked_scores.find { |r| r[:is_bot] }&.dig(:accuracy_score) || 0.0
      ranked_scores.map { |r| r.merge(beats_bot: !r[:is_bot] && r[:accuracy_score] > bot_accuracy) }
    end
  end

  # Inner class for weekly performance
  class WeeklyPerformance
    def initialize(user_id, limit: nil)
      @user_id = user_id
      @limit = limit
      @starting_gameweek = Gameweek::STARTING_GAMEWEEK
    end

    def call
      gameweeks = fetch_gameweeks
      gameweeks.map { |gw_fpl_id| build_gameweek_stats(gw_fpl_id) }
    end

    private

    def fetch_gameweeks
      gameweeks = Forecast.joins(:gameweek)
                          .where(user_id: @user_id)
                          .where("gameweeks.fpl_id >= ?", @starting_gameweek)
                          .group("gameweeks.fpl_id")
                          .pluck("gameweeks.fpl_id")
                          .sort
                          .reverse
      @limit ? gameweeks.first(@limit) : gameweeks
    end

    def build_gameweek_stats(gw_fpl_id)
      scored = Forecast.where(user_id: @user_id)
                       .joins(:gameweek)
                       .where("gameweeks.fpl_id = ?", gw_fpl_id)
                       .where.not(accuracy: nil)

      { gameweek: gw_fpl_id, accuracy_score: (scored.average(:accuracy)&.to_f || 0.0).round(4), forecast_count: scored.count }
    end
  end
end
