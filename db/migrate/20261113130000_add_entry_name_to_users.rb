class AddEntryNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :entry_name, :string
    change_column_null :users, :first_name, true
    change_column_null :users, :last_name, true
  end
end
