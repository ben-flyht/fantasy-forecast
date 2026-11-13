class AddEntryNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :entry_name, :string
    change_column_null :users, :first_name, true
    change_column_null :users, :last_name, true

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE users SET entry_name = first_name || ' ' || LEFT(last_name, 1) || '.'
          WHERE first_name IS NOT NULL AND last_name IS NOT NULL
        SQL
      end
    end
  end
end
