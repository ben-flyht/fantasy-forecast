class AddOptimizationTrackingToStrategies < ActiveRecord::Migration[8.1]
  def change
    add_column :strategies, :last_optimized_at, :datetime
    add_column :strategies, :optimization_log, :jsonb, default: [], null: false
  end
end
