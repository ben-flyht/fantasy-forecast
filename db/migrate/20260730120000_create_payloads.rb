class CreatePayloads < ActiveRecord::Migration[8.0]
  def change
    create_table :payloads do |t|
      t.string :kind, null: false
      t.integer :fpl_id, null: false
      t.references :gameweek, null: false, foreign_key: true
      t.jsonb :data, null: false, default: {}
      t.timestamps
    end

    add_index :payloads, [ :kind, :fpl_id, :gameweek_id ], unique: true,
              name: "index_payloads_on_kind_fpl_id_and_gameweek"

    # "every player as at gameweek N", the shape almost every read will take.
    add_index :payloads, [ :kind, :gameweek_id ]

    # Containment searches over the payload itself: data @> '{"status": "i"}'.
    add_index :payloads, :data, using: :gin
  end
end
