# The newest reading of each figure for each player, answered from an index.
#
# Statistic.latest_by_player asks for the last row per (player, type) in gameweek
# order. Descending is the point of the index: with the gameweek ascending,
# Postgres can only answer by sorting the whole result, which is the work the
# query was written to avoid.
#
# The two indexes dropped are strict prefixes of the new one, and the third is a
# prefix of index_statistics_on_gameweek_type. Every one of their queries is still
# served; they were each another row version to write on every hourly upsert.
class IndexStatisticsByPlayerTypeAndGameweek < ActiveRecord::Migration[8.1]
  def up
    add_index :statistics, [ :player_id, :type, :gameweek_id ],
              order: { gameweek_id: :desc }, name: "index_statistics_on_player_type_gameweek"

    remove_index :statistics, name: "index_statistics_on_player_type"
    remove_index :statistics, name: "index_statistics_on_player_id"
    remove_index :statistics, name: "index_statistics_on_gameweek_id"
  end

  def down
    add_index :statistics, [ :player_id, :type ], name: "index_statistics_on_player_type"
    add_index :statistics, :player_id, name: "index_statistics_on_player_id"
    add_index :statistics, :gameweek_id, name: "index_statistics_on_gameweek_id"

    remove_index :statistics, name: "index_statistics_on_player_type_gameweek"
  end
end
