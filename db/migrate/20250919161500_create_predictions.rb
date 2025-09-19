class CreatePredictions < ActiveRecord::Migration[8.0]
  def change
    create_table :predictions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :week
      t.integer :season_type, null: false
      t.integer :category, null: false

      t.timestamps
    end

    # Unique constraint: one prediction per user/player/week/season_type
    add_index :predictions, [ :user_id, :player_id, :week, :season_type ],
              unique: true, name: 'index_predictions_on_unique_constraint'
  end
end
