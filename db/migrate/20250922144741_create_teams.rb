class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.string :name
      t.string :short_name
      t.integer :fpl_id

      t.timestamps
    end
    add_index :teams, :fpl_id, unique: true
  end
end
