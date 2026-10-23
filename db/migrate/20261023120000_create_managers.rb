class CreateManagers < ActiveRecord::Migration[8.1]
  def change
    create_table :managers do |t|
      t.string :email, null: false
      t.string :nickname, null: false
      t.timestamps
    end
    add_index :managers, "lower(email)", unique: true, name: "index_managers_on_lower_email"
  end
end
