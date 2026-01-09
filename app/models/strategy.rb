class Strategy < ApplicationRecord
  has_many :forecasts, dependent: :nullify

  # Always return strategy_config with symbol keys for consistent access
  def strategy_config
    super&.deep_symbolize_keys
  end

  validate :strategy_config_present
  validate :position_valid, if: -> { position.present? }

  def strategy_config_present
    errors.add(:strategy_config, "can't be nil") if strategy_config.nil?
  end

  def position_valid
    valid_positions = FantasyForecast::POSITION_CONFIG.keys
    errors.add(:position, "must be one of: #{valid_positions.join(', ')}") unless valid_positions.include?(position)
  end

  scope :active, -> { where(active: true) }
  scope :for_position, ->(pos) { where(position: pos) }

  def position_specific?
    position.present?
  end

  def generate_forecasts(gameweek = nil, generate_explanations: true)
    gameweek ||= Gameweek.next_gameweek
    return [] unless gameweek

    position_specific? ? generate_position_forecasts(gameweek, generate_explanations) : generate_all_forecasts(gameweek, generate_explanations)
  end

  def strategy_explanation
    config = strategy_config
    return "Selects players completely at random (no strategy)" if config.empty? || config[:strategies].nil?

    build_explanation(config)
  end

  private

  def generate_position_forecasts(gameweek, generate_explanations)
    PositionForecaster.call(strategy_config:, position:, gameweek:, strategy: self, generate_explanations:)
  end

  def generate_all_forecasts(gameweek, generate_explanations)
    BotForecaster.call(strategy_config:, gameweek:, strategy: self, generate_explanations:)
  end

  def build_explanation(config)
    base = config[:strategies].length == 1 ? explain_single_strategy(config[:strategies].first) : explain_multi_strategy(config[:strategies])
    append_filter_explanation(base, config[:filters])
  end

  def append_filter_explanation(base, filters)
    return base unless filters&.dig(:availability, :min_chance_of_playing)

    min_chance = filters[:availability][:min_chance_of_playing]
    "#{base}, only selecting players #{min_chance}% likely to play"
  end

  def explain_single_strategy(strategy)
    metric_desc = human_metric_name(strategy[:metric])
    lookback = strategy[:lookback]
    base = "Selects players based on #{metric_desc} over the last #{lookback} gameweek#{'s' if lookback > 1}"

    add_recency_description(base, strategy[:recency])
  end

  def add_recency_description(base, recency)
    case recency
    when "linear" then "#{base}, with linear weighting toward more recent matches"
    when "exponential" then "#{base}, with exponential weighting heavily favoring most recent matches"
    else "#{base} (equal weighting)"
    end
  end

  def explain_multi_strategy(strategies)
    parts = strategies.map { |s| format_strategy_part(s) }
    "Composite strategy: #{parts.join(', ')}"
  end

  def format_strategy_part(strategy)
    metric_name = short_metric_name(strategy[:metric])
    weight_pct = (strategy[:weight] * 100).to_i
    lookback = strategy[:lookback]
    recency_desc = strategy[:recency] == "none" ? "" : " (#{strategy[:recency]} recency)"

    "#{weight_pct}% #{metric_name} (#{lookback}GW#{recency_desc})"
  end

  def human_metric_name(metric)
    case metric
    when "total_points", "gameweek_score", "points" then "points"
    when "goals_scored" then "goals"
    when "expected_goals" then "expected goals (xG)"
    when "expected_assists" then "expected assists (xA)"
    when "ict_index" then "ICT index"
    else metric.humanize.downcase
    end
  end

  def short_metric_name(metric)
    case metric
    when "total_points", "gameweek_score", "points" then "points"
    when "goals_scored" then "goals"
    when "expected_goals" then "xG"
    when "expected_assists" then "xA"
    else metric.humanize
    end
  end
end
