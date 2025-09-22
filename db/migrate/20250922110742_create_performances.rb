class CreatePerformances < ActiveRecord::Migration[8.0]
  def change
    create_table :performances do |t|
      t.references :player, null: false, foreign_key: true
      t.references :gameweek, null: false, foreign_key: true
      t.integer :gameweek_score, null: false
      t.integer :total_score, null: false
      t.decimal :ownership_percentage, precision: 5, scale: 2, null: false

      t.timestamps
    end

    add_index :performances, [:player_id, :gameweek_id], unique: true
  end
end
