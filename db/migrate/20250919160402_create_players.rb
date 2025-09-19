class CreatePlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.string :team, null: false
      t.integer :position, null: false
      t.integer :bye_week
      t.integer :fpl_id, null: false

      t.timestamps
    end

    add_index :players, :fpl_id, unique: true
  end
end
