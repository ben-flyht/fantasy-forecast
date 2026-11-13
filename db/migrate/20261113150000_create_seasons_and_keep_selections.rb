class CreateSeasonsAndKeepSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :seasons do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :seasons, :name, unique: true

    add_reference :selections, :season, foreign_key: true
    add_column :selections, :gameweek_number, :integer
    add_column :selections, :archive, :jsonb
    change_column_null :selections, :gameweek_id, true

    reversible do |direction|
      direction.up { backfill }
    end
  end

  private

  def backfill
    first = select_value("SELECT MIN(start_time) FROM gameweeks")
    return unless first

    start = Time.zone.parse(first.to_s)
    year = start.month >= 7 ? start.year : start.year - 1
    name = "#{year}/#{(year + 1).to_s.last(2)}"
    execute "INSERT INTO seasons (name, created_at, updated_at) VALUES (#{quote(name)}, NOW(), NOW())"
    execute <<~SQL.squish
      UPDATE selections SET season_id = (SELECT id FROM seasons WHERE name = #{quote(name)}),
        gameweek_number = (SELECT fpl_id FROM gameweeks WHERE gameweeks.id = selections.gameweek_id)
    SQL
  end
end
