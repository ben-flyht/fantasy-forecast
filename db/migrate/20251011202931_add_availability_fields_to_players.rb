class AddAvailabilityFieldsToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :status, :string
    add_column :players, :chance_of_playing, :integer
  end
end
