class DropOpponentsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :opponents, if_exists: true
  end
end
