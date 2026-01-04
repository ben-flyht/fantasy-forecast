class RemoveUniqueConstraintOnStrategyPosition < ActiveRecord::Migration[8.1]
  def up
    # Remove the unique constraint to allow multiple strategies per position
    # This enables keeping historical strategies while having one active per position
    remove_index :strategies, name: "index_strategies_on_user_id_and_position"
    add_index :strategies, [ :user_id, :position ], name: "index_strategies_on_user_id_and_position", unique: false
  end

  def down
    # Revert to unique constraint - this may fail if duplicates exist
    remove_index :strategies, name: "index_strategies_on_user_id_and_position"
    add_index :strategies, [ :user_id, :position ], name: "index_strategies_on_user_id_and_position", unique: true
  end
end
