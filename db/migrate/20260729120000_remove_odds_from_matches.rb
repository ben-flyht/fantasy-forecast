class RemoveOddsFromMatches < ActiveRecord::Migration[8.0]
  def change
    remove_column :matches, :odds_home_win, :decimal, precision: 6, scale: 3
    remove_column :matches, :odds_draw, :decimal, precision: 6, scale: 3
    remove_column :matches, :odds_away_win, :decimal, precision: 6, scale: 3
  end
end
