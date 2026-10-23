class CreatePackEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :pack_entries do |t|
      t.references :manager, null: false, foreign_key: true
      t.references :weekly_pack, null: false, foreign_key: true
      t.string :hand, null: false
      t.float :expected_points, null: false
      t.timestamps
    end
    add_index :pack_entries, %i[weekly_pack_id manager_id], unique: true
  end
end
