class AddStrategyIdToForecasts < ActiveRecord::Migration[8.0]
  def change
    # Nullable because human users don't have strategies
    add_reference :forecasts, :strategy, null: true, foreign_key: true
  end
end
