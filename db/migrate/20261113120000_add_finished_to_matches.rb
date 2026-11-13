class AddFinishedToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :finished, :boolean, default: false, null: false

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE matches SET finished = TRUE
          WHERE gameweek_id IN (SELECT id FROM gameweeks WHERE is_finished)
        SQL
      end
    end
  end
end
