class AddExplanationToForecasts < ActiveRecord::Migration[8.1]
  def change
    add_column :forecasts, :explanation, :string
  end
end
