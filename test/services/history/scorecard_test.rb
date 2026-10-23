require "test_helper"

module History
  class ScorecardTest < ActiveSupport::TestCase
    test "tied values share the average of their ranks" do
      assert_equal [ 1.0, 2.5, 2.5, 4.0 ], Scorecard.ranks([ 1, 5, 5, 9 ])
    end

    test "a perfect ordering correlates at one" do
      assert_in_delta 1.0, Scorecard.spearman([ 1, 2, 3, 4 ], [ 10, 20, 30, 40 ])
    end

    test "capture, error and bias are marked against what happened" do
      ids = (1..12).to_a
      forecasts = ids.to_h { |id| [ id, id.to_f ] }
      actuals = ids.to_h { |id| [ id, id == 12 ? 0.0 : id.to_f ] }
      scores = Scorecard.call(forecasts: forecasts, actuals: actuals, positions: ids.to_h { |id| [ id, "forward" ] },
                              relevant: [ 11, 12 ])

      best = (2..11).sum
      assert_in_delta (3..11).sum / best.to_f, scores[:capture]
      assert_in_delta Math.sqrt(12.0**2 / 2), scores[:rmse]
      assert_in_delta 6.0, scores[:bias]
    end
  end
end
