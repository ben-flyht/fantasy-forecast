class AddCodeToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :code, :integer
  end
end
