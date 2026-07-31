class AddHorizonToForecasts < ActiveRecord::Migration[8.1]
  def change
    add_column :forecasts, :horizon, :string, null: false, default: "gameweek"

    remove_index :forecasts, name: "index_forecasts_on_player_gameweek"
    add_index :forecasts, %i[player_id gameweek_id horizon],
              name: "index_forecasts_on_player_gameweek_horizon", unique: true
  end
end
