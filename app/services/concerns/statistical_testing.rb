module StatisticalTesting
  extend ActiveSupport::Concern

  private

  def paired_t_test(candidate_gws, baseline_gws)
    differences = candidate_gws.zip(baseline_gws).map { |c, b| c[:capture] - b[:capture] }
    return 1.0 if differences.size < 3

    t_stat, df = t_statistic(differences)
    return 1.0 if t_stat.nil?

    t_to_p(t_stat.abs, df)
  end

  def t_statistic(differences)
    n = differences.size
    mean_diff = differences.sum / n.to_f
    variance = differences.sum { |d| (d - mean_diff)**2 } / (n - 1).to_f
    std_error = Math.sqrt(variance / n)
    return nil if std_error.zero?

    [ mean_diff / std_error, n - 1 ]
  end

  # Two-tailed p-value approximation from t-statistic
  def t_to_p(t, df)
    x = df.to_f / (df + t**2)
    2.0 * incomplete_beta(df / 2.0, 0.5, x) / 2.0
  rescue StandardError
    1.0
  end

  def incomplete_beta(a, b, x) # rubocop:disable Metrics/AbcSize
    return 0.0 if x <= 0.0
    return 1.0 if x >= 1.0

    bt = Math.exp(
      Math.lgamma(a + b)[0] - Math.lgamma(a)[0] - Math.lgamma(b)[0] +
      a * Math.log(x) + b * Math.log(1.0 - x)
    )

    return bt * cf_beta(a, b, x) / a if x < (a + 1.0) / (a + b + 2.0)

    1.0 - bt * cf_beta(b, a, 1.0 - x) / b
  end

  # Continued fraction approximation (Lentz's method) for the incomplete beta function.
  # c and d are mutated across iterations — this is inherently sequential numerical code.
  def cf_beta(a, b, x) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    tiny = 1.0e-30
    c = 1.0
    d = 1.0 / [ 1.0 - (a + b) * x / (a + 1.0), tiny ].max
    h = d

    (1..100).each do |m|
      numerator = m * (b - m) * x / ((a + 2 * m - 1) * (a + 2 * m))
      d = 1.0 / [ 1.0 + numerator * d, tiny ].max
      c = [ 1.0 + numerator / c, tiny ].max
      h *= d * c

      numerator = -(a + m) * (a + b + m) * x / ((a + 2 * m) * (a + 2 * m + 1))
      d = 1.0 / [ 1.0 + numerator * d, tiny ].max
      c = [ 1.0 + numerator / c, tiny ].max
      h *= d * c

      break if (d * c - 1.0).abs < 1.0e-8
    end

    h
  end
end
