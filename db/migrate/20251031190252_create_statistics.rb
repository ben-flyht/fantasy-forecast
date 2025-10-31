class CreateStatistics < ActiveRecord::Migration[8.0]
  def change
    create_table :statistics do |t|
      t.references :player, null: false, foreign_key: true
      t.references :gameweek, null: false, foreign_key: true
      t.string :type, null: false
      t.decimal :value, precision: 10, scale: 2

      t.timestamps
    end

    # Ensure uniqueness: one type per player per gameweek
    add_index :statistics, [:player_id, :gameweek_id, :type], unique: true, name: 'index_statistics_on_player_gameweek_type'

    # Index for querying all stats for a gameweek
    add_index :statistics, [:gameweek_id, :type], name: 'index_statistics_on_gameweek_type'

    # Index for querying player stats across gameweeks
    add_index :statistics, [:player_id, :type], name: 'index_statistics_on_player_type'
  end
end
