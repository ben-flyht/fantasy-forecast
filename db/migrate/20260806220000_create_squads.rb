# The best fifteen the budget can buy, written down rather than worked out while
# somebody watches a page. Searching for it takes thirteen seconds, which is fine
# once an hour and impossible in a request.
#
# One row per gameweek and horizon, the same grain as a forecast, so a squad can be
# marked against what actually happened the same way a forecast is.
class CreateSquads < ActiveRecord::Migration[8.1]
  def change
    create_table :squads do |t|
      t.references :gameweek, null: false, foreign_key: true
      t.string :horizon, null: false, default: "gameweek"
      t.string :formation, null: false
      t.integer :cost, null: false                      # tenths of a million, as FPL counts
      t.decimal :expected_points, precision: 10, scale: 4, null: false
      t.jsonb :picks, null: false, default: []
      t.timestamps
    end

    add_index :squads, [ :gameweek_id, :horizon ], unique: true
  end
end
