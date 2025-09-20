class CreatePlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :players do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :team, null: false
      t.string :position, null: false
      t.string :short_name
      t.integer :fpl_id, null: false
      t.decimal :ownership_percentage, precision: 5, scale: 2, default: 0.0

      t.timestamps
    end

    add_index :players, :fpl_id, unique: true
  end
end