module History
  class Attendance
    UNDISCOUNTED = Backtest::Variant.new(name: "undiscounted", fitness: Backtest::FULLY_FIT)
    PRICE_BANDS = { "under £5.5m" => 0...55, "£5.5–7.4m" => 55...75, "£7.5m and up" => 75.. }.freeze
    OUTFIELD = "outfield".freeze

    Row = Struct.new(:position, :price, :projected, :played, :fixtures, keyword_init: true) do
      def band
        PRICE_BANDS.find { |_, range| range.cover?(price) }&.first
      end

      def line
        position == "goalkeeper" ? position : OUTFIELD
      end
    end

    def initialize(backtest, horizon: "season")
      @backtest = backtest
      @horizon = horizon
    end

    def rows
      @rows ||= @backtest.rounds(@horizon).drop(1).flat_map { |round| rows_at(round) }
    end

    def kept(&group)
      rows.group_by(&group).transform_values do |members|
        members.sum { |row| row.played * row.fixtures } / members.sum { |row| row.projected * row.fixtures }
      end
    end

    private

    def rows_at(round)
      run = @backtest.run(UNDISCOUNTED, @horizon, round)
      last_week = @backtest.season.minutes([ round - 1 ])
      run.rankings.filter_map do |ranking|
        next unless last_week[ranking.player_id].positive?

        row_for(run, ranking)
      end
    end

    def row_for(run, ranking)
      id = ranking.player_id
      projected = projected_share(run, id)
      fixtures = run.fixtures[ranking.team_id].size
      return nil unless projected.positive? && fixtures.positive?

      Row.new(position: ranking.position, price: price(run, id), projected: projected,
              fixtures: fixtures, played: share(run.minutes[id], fixtures))
    end

    def projected_share(run, id)
      share(run.forecasts.dig(id, :working, :minutes).to_f, 1)
    end

    def price(run, id)
      run.stats.dig(id, "now_cost").to_f
    end

    def share(minutes, matches)
      minutes / (ExpectedPoints::FULL_MATCH * matches)
    end
  end
end
