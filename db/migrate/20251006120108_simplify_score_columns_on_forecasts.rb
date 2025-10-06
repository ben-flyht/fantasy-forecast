class SimplifyScoreColumnsOnForecasts < ActiveRecord::Migration[8.0]
  def change
    rename_column :forecasts, :accuracy_score, :accuracy
    remove_column :forecasts, :differential_score, :decimal
    remove_column :forecasts, :total_score, :decimal
  end
end
