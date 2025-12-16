class RemoveStrategyConfigUniqueness < ActiveRecord::Migration[8.0]
  def change
    remove_index :strategies, name: "index_bots_on_strategy_config_uniqueness"
  end
end
