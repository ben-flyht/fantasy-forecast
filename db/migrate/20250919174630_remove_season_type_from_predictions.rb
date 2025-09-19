class RemoveSeasonTypeFromPredictions < ActiveRecord::Migration[8.0]
  def change
    remove_column :predictions, :season_type, :string
  end
end
