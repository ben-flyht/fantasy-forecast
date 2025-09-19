class ChangeEnumColumnsToStrings < ActiveRecord::Migration[8.0]
  def up
    # Add temporary string columns
    add_column :players, :position_string, :string
    add_column :predictions, :season_type_string, :string
    add_column :predictions, :category_string, :string

    # Convert player positions
    execute <<-SQL
      UPDATE players SET position_string = CASE
        WHEN position = 0 THEN 'GK'
        WHEN position = 1 THEN 'DEF'
        WHEN position = 2 THEN 'MID'
        WHEN position = 3 THEN 'FWD'
      END
    SQL

    # Convert prediction season_type
    execute <<-SQL
      UPDATE predictions SET season_type_string = CASE
        WHEN season_type = 0 THEN 'weekly'
        WHEN season_type = 1 THEN 'rest_of_season'
      END
    SQL

    # Convert prediction category (mapping old values to new simplified ones)
    execute <<-SQL
      UPDATE predictions SET category_string = CASE
        WHEN category = 0 THEN 'target'
        WHEN category = 1 THEN 'target'
        WHEN category = 2 THEN 'avoid'
      END
    SQL

    # Remove old integer columns
    remove_column :players, :position
    remove_column :predictions, :season_type
    remove_column :predictions, :category

    # Rename string columns to original names
    rename_column :players, :position_string, :position
    rename_column :predictions, :season_type_string, :season_type
    rename_column :predictions, :category_string, :category

    # Add not null constraints
    change_column_null :players, :position, false
    change_column_null :predictions, :season_type, false
    change_column_null :predictions, :category, false
  end

  def down
    # Add temporary integer columns
    add_column :players, :position_int, :integer
    add_column :predictions, :season_type_int, :integer
    add_column :predictions, :category_int, :integer

    # Convert player positions back
    execute <<-SQL
      UPDATE players SET position_int = CASE
        WHEN position = 'GK' THEN 0
        WHEN position = 'DEF' THEN 1
        WHEN position = 'MID' THEN 2
        WHEN position = 'FWD' THEN 3
      END
    SQL

    # Convert prediction season_type back
    execute <<-SQL
      UPDATE predictions SET season_type_int = CASE
        WHEN season_type = 'weekly' THEN 0
        WHEN season_type = 'rest_of_season' THEN 1
      END
    SQL

    # Convert prediction category back (mapping new values to old ones)
    execute <<-SQL
      UPDATE predictions SET category_int = CASE
        WHEN category = 'target' THEN 0
        WHEN category = 'avoid' THEN 2
      END
    SQL

    # Remove string columns
    remove_column :players, :position
    remove_column :predictions, :season_type
    remove_column :predictions, :category

    # Rename integer columns to original names
    rename_column :players, :position_int, :position
    rename_column :predictions, :season_type_int, :season_type
    rename_column :predictions, :category_int, :category

    # Add not null constraints
    change_column_null :players, :position, false
    change_column_null :predictions, :season_type, false
    change_column_null :predictions, :category, false
  end
end
