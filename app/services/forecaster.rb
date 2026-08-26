# Works out and stores what every player is expected to score over a horizon, and
# ranks them by it. A subclass says which horizon: the coming gameweek, or the
# rest of the season.
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
class Forecaster < ApplicationService
  POSITIONS = %w[goalkeeper defender midfielder forward].freeze

  # FPL's word on whether a player is fit for the coming gameweek. See #fitness_of.
  FITNESS = "chance_of_playing".freeze

  # Not every change that moves the numbers is a tuned number. This one is the
  # reading rule: bump it whenever the same settings would now produce a different
  # forecast, so the new answers are filed apart from the old and a week's results
  # still trace back to what actually produced them.
  #
  # 2: a fitness flag is read from the gameweek being forecast and no earlier one.
  # 3: a club has one goalkeeper's place to share out, and being a bargain is a
  #    matter of degree measured in money rather than a bracket you are in or out of.
  # 4: what a player is paid for is read from what FPL actually pays. An assist is
  #    counted rather than expected, a clean sheet is the chance of one rather than
  #    the share he happened to keep, saves are paid in whole threes, and a full
  #    season of evidence stops being shrunk for doubt it has already answered.
  # 5: a season is a dial rather than a switch. What a player does is read from
  #    this season and last at once, weighted by how much of this one there is,
  #    instead of swapping wholesale at the first whistle and distrusting what
  #    replaced it. Last season's expected assists are read at all, having been
  #    mapped but never loaded.
  MODEL = 5

  def initialize(gameweek: nil)
    @gameweek = gameweek || Gameweek.next_gameweek
  end

  def call
    return log_nothing_to_forecast unless forecastable?

    rows = POSITIONS.flat_map { |position| rows_for(position) }
    return log_nothing_to_forecast if rows.empty?

    store(rows)
    @refused ? false : rows.size
  rescue => e
    Rails.logger.error "#{self.class.name} failed: #{e.message}"
    false
  end

  private

  def store(rows)
    Forecast.upsert_all(rows, unique_by: %i[player_id gameweek_id horizon])
    Rails.logger.info "Forecast #{rows.size} players for gameweek #{@gameweek.fpl_id} (#{horizon})"
  end

  # Which horizon a stored forecast belongs to. The subclass answers.
  def horizon
    raise NotImplementedError
  end

  # The fixtures the forecast is made over. The subclass answers: one gameweek's,
  # or all that remain.
  def matches
    raise NotImplementedError
  end

  def forecastable?
    @gameweek.present? && !@gameweek.is_finished?
  end

  def rows_for(position)
    players = Player.where(position: position).where.not(team_id: nil).to_a
    return [] if players.empty?

    forecasts = expected_points_for(players)
    return refuse(position, players, forecasts) unless anybody_scores?(forecasts)

    rank_rows(players, forecasts)
  end

  def anybody_scores?(forecasts)
    forecasts.any? { |_, forecast| forecast[:points].to_f.positive? }
  end

  def rank_rows(players, forecasts)
    ordered(players, forecasts).each_with_index.map do |player, index|
      row_for(player, forecasts[player.id], index + 1)
    end
  end

  # A whole position scoring nothing is not a forecast, it is a missing input:
  # every player is multiplied by his minutes, his fixtures and his fitness, so
  # one of those being absent takes the lot to nought.
  #
  # Writing that would replace last week's honest numbers with a wall of noughts
  # and empty the page, which is how this last went wrong: three runs reported
  # success while the site showed nothing. So refuse, keep whatever is already
  # stored, and say which input is missing.
  def refuse(position, players, forecasts)
    Rails.logger.error(
      "Refusing to write #{position} forecasts for gameweek #{@gameweek.fpl_id}: " \
      "nobody could be scored. #{missing_inputs(players, forecasts)}"
    )
    @refused = true
    []
  end

  # Which of the three things a forecast is multiplied from was missing.
  INPUTS = {
    "with minutes on record" => ->(w) { w[:minutes].to_i.positive? },
    "with a fixture" => ->(w) { w[:games].to_f.positive? },
    "we could measure" => ->(w) { w[:ours].present? }
  }.freeze

  def missing_inputs(players, forecasts)
    working = forecasts.values.filter_map { |forecast| forecast[:working].presence }
    tally = INPUTS.map { |label, test| "#{working.count(&test)} #{label}" }
    "#{players.size} players, #{tally.join(', ')}"
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
    ExpectedPoints.call(players.map { |player| ranking_for(player) }, **inputs_for(players))
  end

  def inputs_for(players)
    {
      stats: stats_for(players),
      fixtures_by_team: fixtures_by_team,
      season_started: gameweeks_played.positive?,
      gameweeks_played: gameweeks_played,
      managers: total_managers,
      movers: movers,
      fitness: fitness(players)
    }.merge(model_overrides)
  end

  # How fit a player is over this horizon. For one week FPL's own flag answers it,
  # so nothing is passed and the model reads the flag. A horizon long enough for
  # an injury to heal has to ask a different question, and its subclass says so.
  def fitness(_players)
    {}
  end

  # How this horizon departs from the default model. The weekly forecast takes it
  # as it comes; a subclass may turn a knob down. Kept in the strategy tag too, so
  # a stored forecast still says which settings produced it.
  def model_overrides
    {}
  end

  # Asked once for the run rather than once per position: the same four positions
  # were putting the same question to the database four times over.
  def gameweeks_played
    @gameweeks_played ||= Gameweek.finished.count
  end

  def ranking_for(player)
    ConsensusRanking::Ranking.new(player_id: player.id, position: player.position, team_id: player.team_id)
  end

  def row_for(player, forecast, rank)
    now = Time.current
    { player_id: player.id, gameweek_id: @gameweek.id, strategy_id: strategy.id, horizon: horizon,
      rank: rank, score: forecast&.dig(:points), working: forecast&.dig(:working) || {},
      created_at: now, updated_at: now }
  end

  # A player's record as it stood by this gameweek, latest reading first claim.
  #
  # Live this changes nothing, because a forecast for the coming week is made
  # before any later week has a reading to give. It matters when the week is
  # re-run: marking one set of settings against another means making the same
  # forecast twice from the same evidence, and evidence gathered after the
  # football is not evidence, it is hindsight. Left unscoped, a settings change
  # tried in November would be handed November's form to forecast August with,
  # and would beat the settings that had to guess. Every time.
  def stats_for(players)
    stats = record_of(players)
    fitness_of(players).each { |player_id, reading| stats[player_id].merge!(reading) }
    stats
  end

  def record_of(players)
    Statistic.where(player_id: players.map(&:id), type: ExpectedPoints::STAT_TYPES - [ FITNESS ])
             .where(gameweek_id: ..@gameweek.id)
             .latest_by_player
  end

  # A fitness flag is the one reading that must not be carried forward. It says
  # whether a player can play one particular Saturday, and FPL clears it by
  # publishing nothing at all once he is well again. Read as his latest word on
  # the matter, a doubt raised in September is still taking a quarter off him in
  # April, and a nought still has him ruled out of a game he started months ago.
  def fitness_of(players)
    Statistic.where(player_id: players.map(&:id), type: FITNESS, gameweek_id: @gameweek.id)
             .latest_by_player
  end

  def fixtures_by_team
    @fixtures_by_team ||= matches.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |match, fixtures|
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
    @strategy ||= Strategy.find_or_create_by!(strategy_config: settings)
  end

  def settings
    ExpectedPoints.parameters.merge(model_overrides).merge(model: MODEL)
  end

  def log_nothing_to_forecast
    Rails.logger.info "No gameweek to forecast."
    false
  end
end
