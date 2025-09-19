class RemoveByeWeekFromPlayersAndAddShortName < ActiveRecord::Migration[8.0]
  def change
    remove_column :players, :bye_week, :integer
    add_column :players, :short_name, :string
  end
end
