class CreateGameweeks < ActiveRecord::Migration[8.0]
  def change
    create_table :gameweeks do |t|
      t.integer :fpl_id, null: false
      t.string :name, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time
      t.boolean :is_current, default: false, null: false
      t.boolean :is_next, default: false, null: false
      t.boolean :is_finished, default: false, null: false

      t.timestamps
    end
    add_index :gameweeks, :fpl_id, unique: true
  end
end
