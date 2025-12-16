class ChangeChanceOfPlayingDefaultTo100 < ActiveRecord::Migration[8.0]
  def up
    change_column_default :players, :chance_of_playing, 100
    Player.where(chance_of_playing: nil).update_all(chance_of_playing: 100)
  end

  def down
    change_column_default :players, :chance_of_playing, nil
  end
end
