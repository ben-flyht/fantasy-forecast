class RemoveStatusFromPlayers < ActiveRecord::Migration[8.1]
  def change
    remove_column :players, :status, :string
  end
end
