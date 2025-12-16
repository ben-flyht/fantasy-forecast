class AddRankToForecasts < ActiveRecord::Migration[8.0]
  def change
    add_column :forecasts, :rank, :integer
  end
end
