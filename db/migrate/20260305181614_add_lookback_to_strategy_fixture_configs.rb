class AddLookbackToStrategyFixtureConfigs < ActiveRecord::Migration[8.1]
  def up
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config
      next unless config["fixture"].is_a?(Array)

      config["fixture"].each do |fixture_config|
        fixture_config["lookback"] ||= 6
      end

      strategy.update_column(:strategy_config, config)
    end
  end

  def down
    Strategy.where(active: true).find_each do |strategy|
      config = strategy.strategy_config
      next unless config["fixture"].is_a?(Array)

      config["fixture"].each do |fixture_config|
        fixture_config.delete("lookback")
      end

      strategy.update_column(:strategy_config, config)
    end
  end
end
