class RenameEntryNameToUsername < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :entry_name, :username
  end
end
