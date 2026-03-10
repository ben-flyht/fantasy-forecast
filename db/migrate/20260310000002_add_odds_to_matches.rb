class AddOddsToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :odds_home_win, :decimal, precision: 6, scale: 3
    add_column :matches, :odds_draw, :decimal, precision: 6, scale: 3
    add_column :matches, :odds_away_win, :decimal, precision: 6, scale: 3
  end
end
