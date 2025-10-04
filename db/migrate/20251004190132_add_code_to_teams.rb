class AddCodeToTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :teams, :code, :integer
  end
end
