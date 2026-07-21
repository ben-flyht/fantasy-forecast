class RemoveExplanationFromForecasts < ActiveRecord::Migration[8.1]
  def change
    remove_column :forecasts, :explanation, :string
  end
end
