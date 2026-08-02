# A set of parameters a forecast was made with.
#
# It no longer produces forecasts of its own: WeeklyForecast does that, and points
# each row it writes back here, so a week's results can be traced to the settings
# that produced them rather than to whatever the code happens to say today.
class Strategy < ApplicationRecord
  has_many :forecasts, dependent: :nullify

  # Always return strategy_config with symbol keys for consistent access
  def strategy_config
    super&.deep_symbolize_keys
  end

  validate :strategy_config_present

  def strategy_config_present
    errors.add(:strategy_config, "can't be nil") if strategy_config.nil?
  end
end
