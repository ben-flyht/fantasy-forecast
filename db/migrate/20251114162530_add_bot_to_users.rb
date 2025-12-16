class AddBotToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :bot, :boolean, default: false, null: false
  end
end
