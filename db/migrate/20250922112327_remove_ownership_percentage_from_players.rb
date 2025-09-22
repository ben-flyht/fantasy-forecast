class RemoveOwnershipPercentageFromPlayers < ActiveRecord::Migration[8.0]
  def change
    remove_column :players, :ownership_percentage, :decimal
  end
end
