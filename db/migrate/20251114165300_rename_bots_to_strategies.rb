class RenameBotsToStrategies < ActiveRecord::Migration[8.0]
  def change
    rename_table :bots, :strategies
  end
end
