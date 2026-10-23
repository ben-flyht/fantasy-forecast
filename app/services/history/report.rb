module History
  class Report
    SEASONS = {
      "2024-25" => { previous: "2023-24", odds: "2425" },
      "2025-26" => { previous: "2024-25", odds: "2526" }
    }.freeze

    HORIZONS = Backtest::HORIZONS.keys.freeze
    BLOCKS = { "gameweek" => 1, "upcoming" => Horizon::WINDOW, "season" => Backtest::SEASON_LEFT }.freeze
    CALIBRATIONS = [ 0.7, 0.8, 0.9, 1.0 ].freeze
    RECENT_GAMEWEEKS = [ 0, 2, 3, 4, 6 ].freeze
    CONFIDENCE = 1.96
    ATTENDANCE_COLUMNS = [ "Season", *Attendance::PRICE_BANDS.keys.map { |band| "Outfield #{band}" },
                           "Outfield", "Goalkeeper" ].freeze
    GOAL_TESTS = %i[scored fdr conceded fdr].freeze
    ODDS_VARIANTS = { "odds" => [ :odds, ExpectedPoints ],
                      "odds, attack and defence apart" => [ :split, Engines::SplitFixtures ] }.freeze

    def self.season_dir(dir, season)
      File.join(dir, "vaastav", season)
    end

    def self.odds_file(dir, season)
      File.join(dir, "football-data", "#{SEASONS.fetch(season)[:odds]}.csv")
    end

    def initialize(dir, out: $stdout)
      @dir = dir
      @out = out
    end

    def call
      production
      attendance
      odds
      calibration
      recent_minutes
    end

    def production
      heading "The production model"
      table %w[Season Horizon Gameweeks Ranking Capture RMSE Bias Top\ 11], seasons.keys.product(HORIZONS).map { |season, horizon|
        scores = scores(season, horizon, Backtest::PRODUCTION)
        [ season, horizon, scores.size, *%i[spearman capture rmse bias top_eleven].map { |metric| interval(scores, metric) } ]
      }
    end

    def attendance
      heading "What regulars actually play"
      table ATTENDANCE_COLUMNS, kept.map { |season, attendance| attendance_row(season, attendance) }
      table %w[Season Goalkeeper Defender Midfielder Forward], kept.map { |season, attendance| position_row(season, attendance) }
      kept.each_key { |test| out_of_sample(test, other_season(test)) }
    end

    def odds
      heading "Bookmaker odds against FDR"
      table [ "Season", "Goals: odds", "Goals: FDR", "Clean sheets: odds", "Clean sheets: FDR" ],
            seasons.keys.map { |season| goal_row(season) }
      ODDS_VARIANTS.keys.product(seasons.keys).each { |label, season| odds_in_model(label, season) }
    end

    def calibration
      heading "Scoring calibration"
      sweep(CALIBRATIONS.map { |factor| [ factor, Backtest::Variant.new(name: factor.to_s, engine: Engines.calibrated(factor)) ] })
    end

    def recent_minutes
      heading "Recent gameweeks in the minutes blend"
      sweep(RECENT_GAMEWEEKS.map { |weeks| [ weeks, Backtest::Variant.new(name: weeks.to_s, recent_gameweeks: weeks) ] })
    end

    private

    def seasons
      @seasons ||= SEASONS.to_h do |season, sources|
        [ season, Season.from_directory(self.class.season_dir(@dir, season),
                                        previous: self.class.season_dir(@dir, sources[:previous])) ]
      end
    end

    def backtest(season)
      @backtests ||= {}
      @backtests[season] ||= Backtest.new(seasons.fetch(season))
    end

    def odds_for(season)
      @odds ||= {}
      @odds[season] ||= Odds.from_file(self.class.odds_file(@dir, season))
    end

    def scores(season, horizon, variant)
      @scores ||= {}
      @scores[[ season, horizon, variant ]] ||= backtest(season).scores(variant, horizon)
    end

    def pooled(horizon, variant)
      seasons.keys.each_with_object({}) do |season, all|
        scores(season, horizon, variant).each { |round, score| all["#{season}:#{round}"] = score }
      end
    end

    def sweep(variants)
      HORIZONS.each do |horizon|
        base = pooled(horizon, Backtest::PRODUCTION)
        table [ "Setting", "Ranking", "Capture", "RMSE", "Bias", "Top 11", "Likelihood ranking is better", "Likelihood RMSE is better" ],
              variants.map { |setting, variant| sweep_row(setting, base, pooled(horizon, variant), horizon) },
              title: "#{horizon}, both seasons"
      end
    end

    def sweep_row(setting, base, candidate, horizon)
      result = Comparison.call(base, candidate, block: BLOCKS.fetch(horizon))
      [ setting, *%i[spearman capture rmse bias top_eleven].map { |metric| number(result[metric][:candidate]) },
        percent(result[:spearman][:better]), percent(result[:rmse][:better]) ]
    end

    def comparison_table(title, season, horizons, base:, candidate:)
      table %w[Horizon Metric Before After Likelihood\ better], horizons.flat_map { |horizon|
        result = Comparison.call(scores(season, horizon, base), scores(season, horizon, candidate), block: BLOCKS.fetch(horizon))
        result.map do |metric, values|
          [ horizon, metric, number(values[:base]), number(values[:candidate]), percent(values[:better]) ]
        end
      }, title: title
    end

    def attendance_row(season, attendance)
      by_band = attendance.kept { |row| [ row.line, row.band ] }
      by_line = attendance.kept(&:line)
      [ season, *Attendance::PRICE_BANDS.keys.map { |band| percent(by_band[[ Attendance::OUTFIELD, band ]]) },
        percent(by_line[Attendance::OUTFIELD]), percent(by_line["goalkeeper"]) ]
    end

    def odds_in_model(label, season)
      kind, engine = ODDS_VARIANTS.fetch(label)
      ratings = FixtureRatings.new(seasons[season], odds_for(season)).public_send(kind)
      comparison_table("#{label.capitalize} in place of FDR, #{season}", season, [ "gameweek" ],
                       base: Backtest::PRODUCTION, candidate: Backtest::Variant.new(name: label, engine: engine, ratings: ratings))
    end

    def other_season(season)
      (seasons.keys - [ season ]).first
    end

    def kept
      @kept ||= seasons.keys.to_h { |season| [ season, Attendance.new(backtest(season)) ] }
    end

    def position_row(season, attendance)
      by_position = attendance.kept(&:position)
      [ season, *Forecaster::POSITIONS.map { |position| percent(by_position[position]) } ]
    end

    def out_of_sample(test, train)
      variant = Backtest::Variant.new(name: "kept from #{train}", fitness: discount(kept[train].kept(&:line)))
      comparison_table("Fitted on #{train}, tested on #{test}", test, %w[season upcoming],
                       base: Attendance::UNDISCOUNTED, candidate: variant)
    end

    def discount(fitted)
      lambda do |inputs, _window|
        inputs[:rankings].to_h do |ranking|
          [ ranking.player_id, fitted.fetch(ranking.position == "goalkeeper" ? "goalkeeper" : Attendance::OUTFIELD) ]
        end
      end
    end

    def goal_row(season)
      sides = FixtureRatings.new(seasons[season], odds_for(season)).sides
      goals = sides.map { |side| side[:goals] }
      clean = sides.map { |side| side[:conceded].zero? ? 1 : 0 }
      [ season, *GOAL_TESTS.zip([ goals, goals, clean, clean ]).map { |by, outcome| agreement(sides, by, outcome) } ]
    end

    def agreement(sides, by, outcome)
      number(Scorecard.spearman(sides.map { |side| strength(side, by) }, outcome))
    end

    def strength(side, by)
      case by
      when :scored then side[:expected].first
      when :conceded then -side[:expected].last
      else -side[:fdr]
      end
    end

    def interval(scores, metric)
      mean = Comparison.summary(scores)[metric]
      "#{number(mean)} ± #{number(CONFIDENCE * Comparison.spread(scores, metric))}"
    end

    def heading(text)
      @out.puts "\n## #{text}\n\n"
    end

    def table(columns, rows, title: nil)
      @out.puts "**#{title}**\n\n" if title
      @out.puts "| #{columns.join(' | ')} |"
      @out.puts "|#{columns.map { '---' }.join('|')}|"
      rows.each { |row| @out.puts "| #{row.join(' | ')} |" }
      @out.puts
      @out.flush
    end

    def number(value)
      return "–" if value.nil?

      format(value.abs >= 10 ? "%.1f" : "%.3f", value)
    end

    def percent(value)
      return "–" if value.nil?

      "#{(value * 100).round}%"
    end
  end
end
