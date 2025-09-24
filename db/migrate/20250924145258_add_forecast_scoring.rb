class AddForecastScoring < ActiveRecord::Migration[8.0]
  def change
    add_column :forecasts, :accuracy_score, :decimal, precision: 8, scale: 2
    add_column :forecasts, :contrarian_bonus, :decimal, precision: 8, scale: 2
    add_column :forecasts, :total_score, :decimal, precision: 8, scale: 2

    add_index :forecasts, [ :gameweek_id, :total_score ], order: { total_score: :desc }
    add_index :forecasts, [ :user_id, :gameweek_id, :total_score ], order: { total_score: :desc }
  end
end
