class AddSignInSafetyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_signed_in_at, :datetime
    add_column :users, :link_sent_at, :datetime
    add_column :users, :session_token, :string
    add_index :users, :session_token, unique: true
  end
end
