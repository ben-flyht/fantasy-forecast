require "test_helper"

class StatisticalTestingTest < ActiveSupport::TestCase
  class TestHarness
    include StatisticalTesting
    public :paired_t_test
  end

  def setup
    @harness = TestHarness.new
  end

  test "returns p-value near 1 for identical results" do
    gws = 10.times.map { { capture: 0.5 } }
    p_value = @harness.paired_t_test(gws, gws)

    assert_equal 1.0, p_value
  end

  test "returns low p-value for clearly different results" do
    candidate = 20.times.map { |i| { capture: 0.8 + i * 0.01 } }
    baseline = 20.times.map { |i| { capture: 0.4 + i * 0.005 } }

    p_value = @harness.paired_t_test(candidate, baseline)

    assert p_value < 0.01, "Expected p < 0.01 for large consistent difference, got #{p_value}"
  end

  test "returns high p-value for noisy results with small difference" do
    srand(42)
    candidate = 10.times.map { { capture: 0.5 + rand(-0.3..0.3) } }
    baseline = 10.times.map { { capture: 0.5 + rand(-0.3..0.3) } }

    p_value = @harness.paired_t_test(candidate, baseline)

    assert p_value > 0.05, "Expected p > 0.05 for noisy data with small difference, got #{p_value}"
  end

  test "returns 1.0 for fewer than 3 samples" do
    candidate = [ { capture: 0.8 }, { capture: 0.9 } ]
    baseline = [ { capture: 0.4 }, { capture: 0.3 } ]

    p_value = @harness.paired_t_test(candidate, baseline)

    assert_equal 1.0, p_value
  end

  test "p-value is between 0 and 1" do
    candidate = 15.times.map { |i| { capture: 0.6 + i * 0.01 } }
    baseline = 15.times.map { |i| { capture: 0.5 + i * 0.01 } }

    p_value = @harness.paired_t_test(candidate, baseline)

    assert p_value >= 0.0 && p_value <= 1.0, "p-value should be between 0 and 1, got #{p_value}"
  end
end
