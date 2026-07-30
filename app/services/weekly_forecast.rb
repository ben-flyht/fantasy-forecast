# Works out and stores what every player is expected to score in the coming
# gameweek.
#
# Forecasting used to happen while a page was being rendered, which meant the
# figure existed only for as long as somebody was looking at it. A forecast that
# is never written down cannot be checked afterwards, and a model nobody checks
# never improves. So this runs on the hour, stores the number, the rank and the
# working, and tags each one with the parameters that produced it.
#
# It writes only for a gameweek that has not started. Once the football begins the
# forecast is evidence, and evidence must not be quietly rewritten to match what
# happened.
class WeeklyForecast < ApplicationService
  POSITIONS = %w[goalkeeper defender midfielder forward].freeze

  def initialize(gameweek: nil)
    @gameweek = gameweek || Gameweek.next_gameweek
  end

  def call
    return log_nothing_to_forecast unless forecastable?

    rows = POSITIONS.flat_map { |position| rows_for(position) }
    return log_nothing_to_forecast if rows.empty?

    Forecast.upsert_all(rows, unique_by: %i[player_id gameweek_id])
    Rails.logger.info "Forecast #{rows.size} players for gameweek #{@gameweek.fpl_id}"
    rows.size
  rescue => e
    Rails.logger.error "Weekly forecast failed: #{e.message}"
    false
  end

  private

  def forecastable?
    @gameweek.present? && !@gameweek.is_finished?
  end

  def rows_for(position)
    players = Player.where(position: position).where.not(team_id: nil).to_a
    return [] if players.empty?

    forecasts = expected_points_for(players)
    ordered(players, forecasts).each_with_index.map do |player, index|
      row_for(player, forecasts[player.id], index + 1)
    end
  end

  # Most points first, with players we cannot forecast at the bottom: unknown is
  # not the same as good.
  def ordered(players, forecasts)
    players.sort_by do |player|
      points = forecasts.dig(player.id, :points)
      [ points ? 0 : 1, -(points || 0), player.short_name.to_s ]
    end
  end

  def expected_points_for(players)
    ExpectedPoints.new(
      players.map { |player| ranking_for(player) },
      stats: stats_for(players),
      fixtures_by_team: fixtures_by_team,
      season_started: Gameweek.finished.exists?,
      gameweeks_played: Gameweek.finished.count,
      managers: total_managers,
      movers: movers
    ).call
  end

  def ranking_for(player)
    ConsensusRanking::Ranking.new(player_id: player.id, position: player.position, team_id: player.team_id)
  end

  def row_for(player, forecast, rank)
    now = Time.current
    { player_id: player.id, gameweek_id: @gameweek.id, strategy_id: strategy.id,
      rank: rank, score: forecast&.dig(:points), working: forecast&.dig(:working) || {},
      created_at: now, updated_at: now }
  end

  def stats_for(players)
    stats = Hash.new { |hash, key| hash[key] = {} }
    Statistic.where(player_id: players.map(&:id), type: ExpectedPoints::STAT_TYPES)
             .order(:gameweek_id)
             .pluck(:player_id, :type, :value)
             .each { |player_id, type, value| stats[player_id][type] = value.to_f }
    stats
  end

  def fixtures_by_team
    @fixtures_by_team ||= Match.includes(:home_team, :away_team).where(gameweek: @gameweek)
                               .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |match, fixtures|
      add_fixture(fixtures, match, match.home_team_id, match.away_team, home: true)
      add_fixture(fixtures, match, match.away_team_id, match.home_team, home: false)
    end
  end

  # A fixture FPL has not rated is still a fixture. Dropping it would turn a gap in
  # the data into a statement that the team is not playing, which multiplies every
  # player at that club down to nothing.
  def add_fixture(fixtures, match, team_id, opponent, home:)
    fixtures[team_id] << { difficulty: match.difficulty_for(team_id), opponent: opponent&.name, home: home }
  end

  # Players who arrived over the summer, whose minutes record belongs to a
  # different club's team sheet. FPL publishes the date they signed.
  def movers
    @movers ||= Player.where(team_join_date: (@gameweek.start_time.to_date - 120)..).pluck(:id)
  end

  # FPL only publishes a manager count once a gameweek has been ranked, so this is
  # nought all summer and the transfer signal simply stays quiet.
  def total_managers
    @total_managers ||= Payload.events.maximum(Arel.sql("(data->>'ranked_count')::bigint")).to_i
  end

  # The parameters this forecast was made with, matched on the settings themselves
  # rather than on a single row that quietly goes stale. Change a constant and the
  # next run records a new set, while forecasts already made keep pointing at the
  # settings that actually produced them. Without that, a week's results are traced
  # back to whatever the code happens to say today, which is worse than useless
  # when the whole point is to find out which settings were better.
  def strategy
    @strategy ||= Strategy.find_or_create_by!(strategy_config: ExpectedPoints.parameters)
  end

  def log_nothing_to_forecast
    Rails.logger.info "No gameweek to forecast."
    false
  end
end
