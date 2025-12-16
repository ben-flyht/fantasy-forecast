class CreateBots < ActiveRecord::Migration[8.0]
  def change
    create_table :bots do |t|
      t.string :username, null: false
      t.text :description
      t.jsonb :strategy_config, default: {}, null: false
      t.boolean :active, default: true, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :bots, :username, unique: true
    add_index :bots, :active

    # Ensure no two bots have the same strategy configuration
    # Using a hash index on the JSONB column for uniqueness
    execute <<-SQL
      CREATE UNIQUE INDEX index_bots_on_strategy_config_uniqueness
      ON bots USING btree (md5(strategy_config::text))
    SQL
  end
end
