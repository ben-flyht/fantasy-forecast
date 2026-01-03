class RemoveApiFootballIdFromTeams < ActiveRecord::Migration[8.1]
  def change
    remove_index :teams, :api_football_id
    remove_column :teams, :api_football_id, :integer
  end
end
