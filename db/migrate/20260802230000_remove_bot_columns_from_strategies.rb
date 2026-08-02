# A strategy used to be a bot you switched on for a position and tuned over time.
# It is now a record of the parameters a forecast was made with, and a record is
# not something you switch off, assign to a position, or optimise. Nothing has
# read these columns since; they only invited the question of why twelve sets of
# settings were all active at once.
class RemoveBotColumnsFromStrategies < ActiveRecord::Migration[8.1]
  def change
    remove_column :strategies, :active, :boolean, default: true, null: false
    remove_column :strategies, :position, :string
    remove_column :strategies, :last_optimized_at, :datetime
    remove_column :strategies, :optimization_log, :jsonb, default: [], null: false
  end
end
