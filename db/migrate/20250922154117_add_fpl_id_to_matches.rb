class AddFplIdToMatches < ActiveRecord::Migration[8.0]
  def change
    add_column :matches, :fpl_id, :integer
    add_index :matches, :fpl_id, unique: true
  end
end
