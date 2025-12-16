class AddApiFootballIdToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :api_football_id, :integer
    add_index :teams, :api_football_id, unique: true
  end
end
