class CreateForecasts < ActiveRecord::Migration[8.0]
  def change
    create_table :forecasts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :gameweek, null: false, foreign_key: true
      t.string :category, null: false

      t.timestamps
    end

    # Unique constraint: one forecast per user/player/gameweek
    add_index :forecasts, [ :user_id, :player_id, :gameweek_id ],
              unique: true, name: 'index_forecasts_on_unique_constraint'
  end
end