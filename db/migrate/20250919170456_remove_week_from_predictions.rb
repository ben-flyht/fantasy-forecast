class RemoveWeekFromPredictions < ActiveRecord::Migration[8.0]
  def change
    remove_column :predictions, :week, :integer
  end
end
