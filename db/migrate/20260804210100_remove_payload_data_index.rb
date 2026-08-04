# A GIN index over every payload we hold, rebuilt for eight hundred players an
# hour, to serve containment searches nobody makes. The one query that reads a
# payload takes the highest ranked_count across at most thirty-eight gameweek
# rows, which no index helps with.
#
# The archive is kept for the day a strategy wants a field nobody thought to map.
# On that day the index for the query it turns out to want is one line away.
class RemovePayloadDataIndex < ActiveRecord::Migration[8.1]
  def up
    remove_index :payloads, name: "index_payloads_on_data"
  end

  def down
    add_index :payloads, :data, using: :gin, name: "index_payloads_on_data"
  end
end
