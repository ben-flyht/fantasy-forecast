class AddOwnershipPercentageToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :ownership_percentage, :decimal, precision: 5, scale: 2, default: 0.0
  end
end
