module History
  class Backtest
    Variant = Struct.new(:name, :engine, :recent_gameweeks, :ratings, :fitness, keyword_init: true) do
      def initialize(name:, engine: ExpectedPoints, recent_gameweeks: Forecaster::RECENT_GAMEWEEKS,
                     ratings: nil, fitness: nil)
        super
      end
    end

    Run = Struct.new(:round, :window, :rankings, :stats, :forecasts, :actuals, :minutes, :fixtures,
                     keyword_init: true) do
      def points
        forecasts.transform_values { |result| result[:points] }
      end

      def positions
        rankings.to_h { |ranking| [ ranking.player_id, ranking.position ] }
      end
    end

    PRODUCTION = Variant.new(name: "production")
    FULLY_FIT = ->(*) { {} }
    SEASON_KEPT = lambda do |inputs, _window|
      inputs[:rankings].to_h { |ranking| [ ranking.player_id, SeasonForecast::MINUTES_KEPT.fetch(ranking.position) ] }
    end

    HORIZONS = {
      "gameweek" => { weeks: 1, overrides: {}, fitness: FULLY_FIT },
      "upcoming" => { weeks: Horizon::WINDOW, fitness: FULLY_FIT,
                      overrides: { clamp_width: UpcomingForecast::CLAMP_WIDTH,
                                   new_club_minutes: UpcomingForecast::NEW_CLUB_MINUTES } },
      "season" => { weeks: nil, fitness: SEASON_KEPT,
                    overrides: { clamp_width: SeasonForecast::CLAMP_WIDTH,
                                 new_club_minutes: SeasonForecast::NEW_CLUB_MINUTES } }
    }.freeze

    SEASON_LEFT = 10
    RELEVANT_OWNERSHIP = 1.0
    RELEVANT_POINTS = 2.0

    attr_reader :season

    def initialize(season, reference: PRODUCTION)
      @season = season
      @reference = reference
    end

    def rounds(horizon)
      weeks = HORIZONS.fetch(horizon)[:weeks] || SEASON_LEFT
      @season.rounds.select { |round| window(horizon, round).size >= weeks }
    end

    def window(horizon, round)
      weeks = HORIZONS.fetch(horizon)[:weeks]
      later = @season.rounds.select { |candidate| candidate >= round }
      weeks ? later.first(weeks) : later
    end

    def scores(variant, horizon)
      rounds(horizon).to_h do |round|
        run = run(variant, horizon, round)
        [ round, Scorecard.call(forecasts: run.points, actuals: run.actuals, positions: run.positions,
                                relevant: relevant(horizon, round)) ]
      end
    end

    def run(variant, horizon, round)
      inputs = inputs(round, variant.recent_gameweeks)
      span = window(horizon, round)
      fixtures = @season.fixtures_by_team(span, difficulty: variant.ratings)
      Run.new(round: round, window: span, rankings: inputs[:rankings], stats: inputs[:stats],
              forecasts: forecast(variant, horizon, inputs, fixtures, span),
              actuals: actuals(span), minutes: minutes(span), fixtures: fixtures)
    end

    def relevant(horizon, round)
      @relevant ||= {}
      @relevant[[ horizon, round ]] ||= begin
        run = run(@reference, horizon, round)
        weeks = run.window.size
        run.rankings.map(&:player_id).select do |id|
          run.stats.dig(id, "selected_by_percent").to_f >= RELEVANT_OWNERSHIP ||
            run.points[id].to_f / weeks >= RELEVANT_POINTS
        end
      end
    end

    private

    def forecast(variant, horizon, inputs, fixtures, span)
      settings = HORIZONS.fetch(horizon)
      fitness = (variant.fitness || settings[:fitness]).call(inputs, span)
      context = inputs.slice(:stats, :season_started, :gameweeks_played, :managers, :movers)
      inputs[:rankings].group_by(&:position).each_with_object({}) do |(_, rankings), forecasts|
        variant.engine.call(rankings, fixtures_by_team: fixtures, fitness: fitness, **context, **settings[:overrides])
               .each { |id, result| forecasts[id] = result }
      end
    end

    def inputs(round, recent_gameweeks)
      @inputs ||= {}
      @inputs[[ round, recent_gameweeks ]] ||= @season.inputs(round, recent_gameweeks: recent_gameweeks)
    end

    def actuals(span)
      @actuals ||= {}
      @actuals[span] ||= @season.points(span)
    end

    def minutes(span)
      @minutes ||= {}
      @minutes[span] ||= @season.minutes(span)
    end
  end
end
