class Strategy < ApplicationRecord
  belongs_to :user
  has_many :forecasts, dependent: :nullify

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

  delegate :username, to: :user

  # Check if this is a position-specific strategy
  def position_specific?
    position.present?
  end

  # Generate forecasts for this strategy
  # Position-specific strategies only generate forecasts for their position
  def generate_forecasts(gameweek = nil)
    gameweek ||= Gameweek.next_gameweek
    return [] unless gameweek

    if position_specific?
      # Position-specific strategy: only generate for this position
      PositionForecaster.call(
        user:,
        strategy_config: strategy_config.deep_symbolize_keys,
        position:,
        gameweek:,
        strategy: self  # Link forecasts to this strategy
      )
    else
      # Global strategy: generate for all positions
      BotForecaster.call(user:, strategy_config: strategy_config.deep_symbolize_keys, gameweek:, strategy: self)
    end
  end

  # Generate a human-readable explanation of the strategy
  def strategy_explanation
    return description if description.present?

    config = strategy_config.deep_symbolize_keys

    if config.empty? || config[:strategies].nil?
      return "Selects players completely at random (no strategy)"
    end

    strategies = config[:strategies]
    filters = config[:filters]

    base_explanation = if strategies.length == 1
      strategy = strategies.first
      explain_single_strategy(strategy)
    else
      explain_multi_strategy(strategies)
    end

    # Add filter explanations if present
    if filters&.dig(:availability, :min_chance_of_playing)
      min_chance = filters[:availability][:min_chance_of_playing]
      base_explanation += ", only selecting players #{min_chance}% likely to play"
    end

    base_explanation
  end

  private

  def explain_single_strategy(strategy)
    metric = strategy[:metric]
    lookback = strategy[:lookback]
    recency = strategy[:recency]

    # Human-friendly metric names
    metric_desc = case metric
    when "total_points", "gameweek_score", "points"
      "points"
    when "goals_scored"
      "goals"
    when "expected_goals"
      "expected goals (xG)"
    when "expected_assists"
      "expected assists (xA)"
    when "ict_index"
      "ICT index"
    else
      metric.humanize.downcase
    end

    base = "Selects players based on #{metric_desc} over the last #{lookback} gameweek#{'s' if lookback > 1}"

    case recency
    when "linear"
      "#{base}, with linear weighting toward more recent matches"
    when "exponential"
      "#{base}, with exponential weighting heavily favoring most recent matches"
    else
      "#{base} (equal weighting)"
    end
  end

  def explain_multi_strategy(strategies)
    parts = strategies.map do |strategy|
      metric_name = case strategy[:metric]
      when "total_points", "gameweek_score", "points"
        "points"
      when "goals_scored"
        "goals"
      when "expected_goals"
        "xG"
      when "expected_assists"
        "xA"
      else
        strategy[:metric].humanize
      end

      weight_pct = (strategy[:weight] * 100).to_i
      lookback = strategy[:lookback]
      recency_desc = strategy[:recency] == "none" ? "" : " (#{strategy[:recency]} recency)"

      "#{weight_pct}% #{metric_name} (#{lookback}GW#{recency_desc})"
    end

    "Composite strategy: #{parts.join(', ')}"
  end
end
