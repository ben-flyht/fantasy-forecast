class CreateWeeklyPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :weekly_packs do |t|
      t.references :gameweek, null: false, foreign_key: true, index: { unique: true }
      t.integer :seed, null: false
      t.jsonb :pairs, null: false, default: []
      t.timestamps
    end
  end
end
