class CreatePackGames < ActiveRecord::Migration[8.1]
  def change
    create_table :managers do |t|
      t.string :email, null: false
      t.timestamps
    end
    add_index :managers, "lower(email)", unique: true, name: "index_managers_on_lower_email"

    create_table :weekly_packs do |t|
      t.references :gameweek, null: false, foreign_key: true, index: { unique: true }
      t.integer :seed, null: false
      t.jsonb :pairs, null: false, default: []
      t.timestamps
    end

    create_table :pack_entries do |t|
      t.references :manager, null: false, foreign_key: true
      t.references :weekly_pack, null: false, foreign_key: true
      t.string :hand, null: false
      t.timestamps
    end
    add_index :pack_entries, %i[weekly_pack_id manager_id], unique: true
  end
end
