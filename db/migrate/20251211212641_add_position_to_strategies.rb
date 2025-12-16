class AddPositionToStrategies < ActiveRecord::Migration[8.0]
  def change
    add_column :strategies, :position, :string
    add_index :strategies, [ :user_id, :position ], unique: true, where: "position IS NOT NULL"
  end
end
