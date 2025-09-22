class AddTeamToPlayers < ActiveRecord::Migration[8.0]
  def change
    # Remove the old string team column
    remove_column :players, :team, :string if column_exists?(:players, :team)

    # Add the new team reference
    add_reference :players, :team, null: true, foreign_key: true
  end
end
