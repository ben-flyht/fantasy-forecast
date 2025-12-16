class RemoveUnusedColumns < ActiveRecord::Migration[8.0]
  def change
    # chance_of_playing is now stored historically in statistics table
    remove_column :players, :chance_of_playing, :integer, default: 100

    # description was never used
    remove_column :strategies, :description, :text
  end
end
