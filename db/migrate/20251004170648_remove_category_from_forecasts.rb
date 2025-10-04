class RemoveCategoryFromForecasts < ActiveRecord::Migration[8.0]
  def change
    remove_column :forecasts, :category, :string
  end
end
