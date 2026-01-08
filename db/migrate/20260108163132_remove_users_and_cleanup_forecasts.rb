class RemoveUsersAndCleanupForecasts < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Get the bot user ID before we do anything
    bot_user_id = execute("SELECT id FROM users WHERE bot = true LIMIT 1").first&.dig("id")

    # Step 2: Delete all non-bot forecasts (keep only bot forecasts)
    if bot_user_id
      execute("DELETE FROM forecasts WHERE user_id != #{bot_user_id}")
    else
      # If no bot user exists, delete all forecasts (shouldn't happen in practice)
      execute("DELETE FROM forecasts")
    end

    # Step 3: Remove user_id foreign key and column from forecasts
    remove_foreign_key :forecasts, :users if foreign_key_exists?(:forecasts, :users)
    remove_index :forecasts, name: "index_forecasts_on_user_id" if index_exists?(:forecasts, :user_id, name: "index_forecasts_on_user_id")
    remove_index :forecasts, name: "index_forecasts_on_user_id_and_gameweek_id" if index_exists?(:forecasts, [ :user_id, :gameweek_id ], name: "index_forecasts_on_user_id_and_gameweek_id")
    remove_index :forecasts, name: "index_forecasts_on_unique_constraint" if index_exists?(:forecasts, [ :user_id, :player_id, :gameweek_id ], name: "index_forecasts_on_unique_constraint")
    remove_column :forecasts, :user_id
    remove_column :forecasts, :accuracy

    # Step 4: Add new uniqueness constraint (one forecast per player per gameweek)
    add_index :forecasts, [ :player_id, :gameweek_id ], unique: true, name: "index_forecasts_on_player_gameweek"

    # Step 5: Remove user_id from strategies
    remove_foreign_key :strategies, :users if foreign_key_exists?(:strategies, :users)
    remove_index :strategies, name: "index_strategies_on_user_id" if index_exists?(:strategies, :user_id, name: "index_strategies_on_user_id")
    remove_index :strategies, name: "index_strategies_on_user_id_and_position" if index_exists?(:strategies, [ :user_id, :position ], name: "index_strategies_on_user_id_and_position")
    remove_column :strategies, :user_id

    # Step 6: Drop users table
    drop_table :users
  end

  def down
    # Recreate users table
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :username, null: false
      t.string :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string :unconfirmed_email
      t.boolean :bot, null: false, default: false
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :username, unique: true
    add_index :users, :confirmation_token, unique: true

    # Re-add user_id to strategies
    add_column :strategies, :user_id, :bigint
    add_index :strategies, :user_id
    add_index :strategies, [ :user_id, :position ]
    add_foreign_key :strategies, :users

    # Re-add user_id and accuracy to forecasts
    remove_index :forecasts, name: "index_forecasts_on_player_gameweek"
    add_column :forecasts, :user_id, :bigint
    add_column :forecasts, :accuracy, :decimal, precision: 8, scale: 2
    add_index :forecasts, :user_id
    add_index :forecasts, [ :user_id, :gameweek_id ]
    add_index :forecasts, [ :user_id, :player_id, :gameweek_id ], unique: true, name: "index_forecasts_on_unique_constraint"
    add_foreign_key :forecasts, :users
  end
end
