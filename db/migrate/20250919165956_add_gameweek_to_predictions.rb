class AddGameweekToPredictions < ActiveRecord::Migration[8.0]
  def change
    add_reference :predictions, :gameweek, null: true, foreign_key: true
  end
end
