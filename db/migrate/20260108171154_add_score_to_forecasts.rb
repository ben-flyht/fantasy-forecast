class AddScoreToForecasts < ActiveRecord::Migration[8.1]
  def change
    add_column :forecasts, :score, :decimal, precision: 10, scale: 4
  end
end
