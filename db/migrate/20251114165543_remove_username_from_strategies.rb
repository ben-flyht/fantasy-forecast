class RemoveUsernameFromStrategies < ActiveRecord::Migration[8.0]
  def change
    remove_index :strategies, :username
    remove_column :strategies, :username, :string
  end
end
