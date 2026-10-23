class CreateUsersAndSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.timestamps
    end
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"

    create_table :selections do |t|
      t.references :user, null: false, foreign_key: true
      t.references :gameweek, null: false, foreign_key: true
      t.jsonb :offered, null: false, default: []
      t.string :picks, null: false, default: ""
      t.timestamps
    end
    add_index :selections, %i[gameweek_id user_id], unique: true
  end
end
