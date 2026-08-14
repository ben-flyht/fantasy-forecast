# A tally of the comparisons people actually ask for, one row per canonical address.
#
# Every pair of players has an address, which is more addresses than anybody could
# read; the ones worth offering on the hub are the ones somebody has asked. So each
# request bumps a count against its canonical slug, and the hub reads the top of them
# back. See MostRequestedComparisons for what it surfaces, which is pairs only.
class CreateComparisonRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :comparison_requests do |t|
      t.string :slug, null: false
      t.integer :hits, null: false, default: 0
      # Whether the address is a straight pair. The hub and the sitemap surface pairs
      # only, so the column lets them read the top pairs without parsing — and so
      # never resolving — a group slug somebody may have crafted to be expensive.
      t.boolean :pair, null: false, default: false
      t.timestamps
    end

    add_index :comparison_requests, :slug, unique: true
    add_index :comparison_requests, [ :pair, :hits ]
  end
end
