class AddNewsToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :news, :string
  end
end
