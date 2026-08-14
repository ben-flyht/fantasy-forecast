# A tally of the comparisons people ask for, one row per canonical address per
# gameweek, so the hub can offer the arguments managers actually have — and offer a
# fresh set each week, because the question that mattered a fortnight ago is not the
# one people are stuck on now.
#
# See MostRequestedComparisons for what is surfaced, which is pairs only; the `pair`
# column lets that read the top pairs without ever resolving a group slug somebody may
# have crafted to be expensive.
class CreateComparisons < ActiveRecord::Migration[8.1]
  def change
    create_table :comparisons do |t|
      t.references :gameweek, null: false, foreign_key: true
      t.string :slug, null: false
      t.integer :hits, null: false, default: 0
      t.boolean :pair, null: false, default: false
      t.timestamps
    end

    add_index :comparisons, [ :gameweek_id, :slug ], unique: true
    add_index :comparisons, [ :gameweek_id, :pair, :hits ]
  end
end
